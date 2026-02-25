# Flavortown Agent Instructions

## Environment

Check with the user if the local setup uses docker. If so run anything using `docker compose run --service-ports web COMMAND`.
You can't run in an interactive docker shell but you can execute one-off commands.

## Build & Test Commands

- **Run all tests**: `bin/rails test`
- **Lint & Fix**: `bin/lint`
- **Start dev server**: `bin/dev`
- **Database setup**: `bin/rails db:prepare`

## Architecture & Structure

- **Framework**: Ruby on Rails 8.1.
- **Database**: PostgreSQL with `solid_queue` (jobs).
- **Caching**: Redis (`redis_cache_store`) in production, `memory_store` in development.
- **Key Gems**:
  - `pundit` (Authorization)
  - `aasm` (State Machines)
  - `paper_trail` (Versioning)
  - `flipper` (Feature Flags)
  - `view_component` (UI Components)
- **Deployment**: Coolify (Docker-based), not Kamal.

## Code Style & Conventions

- **Style**: Follows `rubocop-rails-omakase` defaults.
- **Testing**: Use **Minitest** (default Rails testing). Do not use RSpec.
  - Fixtures are used for test data (`test/fixtures/`).
- **Frontend**:
  - Use `esbuild` for JS and `dartsass-rails` for CSS.
  - Place controllers in `app/javascript/controllers`.
- **Security**:
  - Use `lockbox` and `blind_index` for encrypted fields.
  - Ensure `pundit` policies are applied in controllers.

When making changes/creations towards admin sides of the codebase there needs to be proper papertrail code and audit logging which should be accessible.

DB migrations should always ask for user confirmation.

When making code changes that require migrations, always use `bin/rails generate migration` instead of manually creating migration files. Manually creating migrations can cause issues when the AI generates improper migration syntax or timestamps.

Bias for rails generators (ie. rails g model/migration) when first creating a file.

We want maintainable code! Please use proper code formatting and naming conventions, also please use css classes instead of raw `style=` attributes, if possible use already existing components or partials.

When coding please do not produce unnecessary code or any dead code, if u make dead code please make sure to remove it and clean it up!

## Cursor Cloud specific instructions

### Running without Docker

In the cloud agent environment, the app runs **locally** (not via Docker Compose). PostgreSQL runs in a Docker container on `localhost:5432`.

- `DATABASE_URL` and `TEST_DATABASE_URL` must be exported in the shell (the `.env` file exists but `dotenv-rails` 3.x loads too late for some `db:` rake tasks). Use the same credentials as in `docker-compose.yml` and `example.env`, pointing at `localhost:5432`.
- The `config/database.yml` test section includes `url: <%= ENV['TEST_DATABASE_URL'] %>` to support TCP connections (the upstream config assumes Unix sockets from Docker).
- Development credentials are stored in `config/credentials/development.key` (gitignored). If missing, regenerate with:
  ```
  EDITOR="cp /path/to/creds.yml" bin/rails credentials:edit --environment=development
  ```
  See `docs/example_dev_creds.yml` for the template.

### Starting the dev server

`bin/dev` uses Foreman with `Procfile.dev` (web + css + js watchers). When running in a backgrounded shell, esbuild's `--watch` flag exits because stdin closes. Workarounds:
1. Build assets once (`yarn build && bin/rails dartsass:build`), then start just the Rails server: `bin/rails server -b 0.0.0.0 -p 3000`
2. Or use a pseudo-terminal wrapper to keep stdin open for Foreman.

### Dev login

The landing page at `localhost:3000` has a "dev login" link that bypasses OAuth for local testing.

### Tests (pre-existing issue)

The test suite (`bin/rails test`) is disabled in CI. Tests fail due to a fixture issue: `test/fixtures/hcb_credentials.yml` references virtual `lockbox` attributes (`refresh_token`, `access_token`) that don't exist as real database columns. This is a pre-existing compatibility issue.

### CI checks that are active

See `.github/workflows/ci.yml`. The active jobs are: `scan_ruby` (brakeman), `lint` (rubocop + erb_lint + prettier), `zeitwerk_check`, and `db_checks` (schema + annotations). The `test` job is commented out.
