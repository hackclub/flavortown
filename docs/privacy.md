# Privacy requests (GDPR deletion and export)

Deletion and export requests are run from the Hack Club privacy hub at https://yeet.hackclub.com. The hub calls these endpoints once with `dry_run: true`. A human reviews the result, and after approval the hub calls again for real.

| Endpoint | Does |
| --- | --- |
| `POST /api/privacy/delete` | Erases the subject, or reports what would be erased on a dry run |
| `POST /api/privacy/export` | Reports what is held. Export delivery isn't specified yet, so it never changes anything |

`Api::PrivacyController` inherits `ActionController::API`, so none of `ApplicationController`'s session, ban or tracking callbacks run.

## Authentication

Each call carries `Authorization: Bearer <token>`: an ES256 JWT signed by the hub. `Privacy::Token` verifies it with Ruby's OpenSSL against the hub's JWKS (`https://yeet.hackclub.com/.well-known/jwks.json`). It checks:

- the signature, `kid`, and `typ: JWT`
- `iss` is `hackclub-privacy` and `aud` is `flavortown`
- `exp` and `iat`, with a lifetime of at most 300 seconds and 30 seconds of leeway
- the shape of the claims

Keys are cached for 5 minutes and refetched when an unknown `kid` shows up, so key rotation on the hub needs no change here. Nothing needs configuring in production; `PRIVACY_JWKS_URL` only exists to point at a hub running locally.

The endpoints act only on the token claims, never the request body. Each token's `jti` is accepted once: used IDs go in `privacy_token_uses`, pruned after a day. They live in Postgres rather than `Rails.cache` because the Redis cache store reports a failed write the same way as an existing key, which would make every token look replayed.

Responses:

- `200 {request_id, found, dry_run, deleted: {table: rows}, retained: [{type, count, reason}]}`. Once someone is erased, later calls answer `found: false`.
- `401 {error}` for a bad token, `400 action_mismatch`, `409 replayed`
- `503` when the JWKS can't be fetched. The hub retries.

## Who is matched

Users whose `email` or `hcb_email` matches one of the subject's emails (case-insensitively), whose `slack_id` matches, or whose Hack Club identity (`user_identities.uid` with provider `hack_club`) matches `identity_id`.

## How erasure works

Shop orders, ledger entries, payouts, card grants, warehouse packages, votes and reports all hold required foreign keys to `users`, and ledger entries are immutable by design. So the user row is kept as an **anonymous placeholder** rather than deleted, and everything personal is deleted or cleared. `Privacy::Eraser` does it all in one transaction, mostly in SQL so model callbacks (ledger guards, payout recalculation jobs) don't fire.

### The account

The `users` row keeps its id and non-personal settings. These are cleared:

- email, HCB email, first, last and display name (display name becomes "Deleted user")
- Slack ID (becomes `deleted-<id>` to satisfy its presence and uniqueness validation)
- API key, session and magic-link tokens, ref, Airtable record id, internal notes, ban reason, club, regions, and granted roles

Ledger entries a reviewer created (`created_by` of "Name (id)") are relabelled "Deleted user (id)".

With the identities gone and the email cleared, signing in again creates a new account, and the Airtable user syncs skip the row because it has no email.

### Deleted

- login identities, profile, project memberships, follows, skips, Flavortime sessions, extension usage, Hackatime project links and time-loss audits, shop suggestions, and messages to them
- comments and likes they made. Other people's like and comment counts are recounted.
- their devlogs and git commit posts in any project, with the devlogs' likes, comments, edit history and attachments. Git commits elsewhere authored with their email have the author cleared.
- funnel events and RSVPs for their user id or emails
- Disco recommendations for them, Flipper actor gates, and PaperTrail versions of everything above. `whodunnit` is cleared where it was them.
- Ahoy visits and events, when the Ahoy database is configured. Those go first, before the main transaction, since they live in another database.

### Projects

A project where every current member is being erased is soft-deleted (`deleted_at`) and kept as a hidden placeholder, because ship events, votes and payouts reference it. Its title becomes "Deleted project". Its description, links and AI declaration are cleared, the banner and demo video are purged, all of its devlogs and commits are deleted, and ship event bodies are cleared.

In a project shared with people who stay, only their membership and their own devlogs and commits go. Any other posts of theirs stay with `user_id` cleared. Member counts, devlog counts and durations are recounted.

### Closed

Open shop orders (`pending`, `awaiting_verification`, `awaiting_verification_call`, `awaiting_periodical_fulfillment`, `on_hold`) are rejected with the reason "Cancelled: account deleted after a privacy request", so nothing ships to a deleted account. No refund is made, because the balance goes with the account.

### Kept, and reported as `retained`

| Kept | Why |
| --- | --- |
| The account row | Anonymous placeholder so financial records stay linked |
| Shop orders, packages, card grants, ledger entries, fulfillment payouts, show and tell attendances, achievements | Accounting, fulfilment and customs; the ledger must balance |
| Votes cast | Other projects' rankings and payouts |
| Reports filed and order reviews | Fraud prevention and the record of staff decisions |
| Projects they solely owned | Hidden placeholders, see above |
| Airtable copies | Not touched here; the hub's Airtable target deletes them |

Order addresses (`frozen_address`) stay on retained orders for fulfilment and customs.

## Dry runs

A dry run performs the real erasure inside a transaction, reads the per-table delete counts Postgres tracks for it (`pg_stat_xact_user_tables`), and rolls back. Dry run and real run share one code path, so the reviewed numbers are the executed numbers. Attachment blobs are purged only after a real run commits.

## Not covered

- Sentry, which runs with `send_default_pii`, and Skylight or `rails_performance` data.
- Slack messages already sent, and copies held by HCB, Theseus or the ship-cert dashboard.
- Extension usage still buffered in Redis when the erasure runs is flushed to the placeholder afterwards.

## Running it against a local hub

```sh
# .env
PRIVACY_JWKS_URL=http://host.docker.internal:44100/.well-known/jwks.json
```

In the hub, register a target with slug and audience `flavortown` and base URL `http://127.0.0.1:3000`.
