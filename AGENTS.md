# Battlemage Agent Instructions

## Build & Test Commands

- **Run all tests**: `bin/rails test`
- **Run single test file**: `bin/rails test test/models/user_test.rb`
- **Run specific test case**: `bin/rails test test/models/user_test.rb:10`
- **Lint Ruby**: `bundle exec rubocop`
- **Lint ERB**: `bundle exec erb_lint --lint-all`
- **Fix Ruby issues**: `bundle exec rubocop -A`
- **Start dev server**: `bin/dev`
- **Database setup**: `bin/rails db:prepare`

## Architecture & Structure

- **Framework**: Ruby on Rails 8.1 using **Hotwire** (Turbo + Stimulus) for frontend.
- **Database**: PostgreSQL with `solid_queue` (jobs) and `solid_cache` (caching).
- **Key Gems**:
  - `pundit` (Authorization)
  - `aasm` (State Machines)
  - `paper_trail` (Versioning)
  - `flipper` (Feature Flags)
  - `view_component` (UI Components)
- **Deployment**: Kamal (Docker-based).

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

When making making changes/creations towards admin sides of the codebase there needs to be proper papertrail code and audit logging which should be accessible.

DB migrations should always ask for user confirmation.
