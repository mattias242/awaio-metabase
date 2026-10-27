# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Awaio is a booking and entity management system that integrates with the Awaio API. The project fetches data from the Awaio API (bookings, entities) and stores it in a local PostgreSQL database for analysis with Metabase.

## Development workflow: TDD RED → GREEN → BLUE

All code changes (`fetch_*.py`, `anonymize.py`, `scheduler_loop.py`, new modules) follow a strict three-phase cycle, one cycle per behavior:

1. **RED** — Write a test that captures the desired behavior. Run it. Confirm it fails *at the assertion level* (not because of a missing import or directory). Show the failure before writing any implementation.
2. **GREEN** — Write the minimum implementation needed to make the test pass. Nothing more. Run the test, confirm it passes.
3. **BLUE** (refactor) — Clean up code *and* test while keeping the suite green. Run the full suite after, confirm still green.

Each cycle is small: one behavior, one test, one impl pass. A feature with N behaviors = N cycles, not one big cycle.

When fixing a failing test, decide which is truth before editing:
- **Test drives behavior** → fix the implementation. This is the TDD path.
- **Test couples to implementation detail** (e.g. mocked `headers=`, `timeout=`, internal helper names) → rewrite the assertion to assert behavior (URL, body, return value) instead of impl coupling. Loosening the matcher to "match whatever impl does now" is anti-TDD.

Anti-TDD shortcuts (e.g. obvious typo fixes, pure refactors with no behavior change) are allowed but must be called out explicitly: *"skipping RED — no behavior change."*

SQL views (`sql/views/*.sql`) and Metabase models (`metabase/models/*.sql`) don't have pytest coverage, but follow the same spirit: write a `SELECT` that returns the wrong/empty result, then build the view/model until the SELECT returns expected output.

## Deployment Environment

This project runs on **Windows 11 with Docker Desktop** (native PowerShell or WSL2).

- **Docker Compose**: `docker-compose.yml` (the only compose file — tuned for Windows with memory limits and TZ)
- **Env file**: `.env.example` (copied to `.env` by the setup script)
- **PostgreSQL port**: 5433 (to avoid a conflict with a local PostgreSQL)
- **Setup script**: `windows-setup.ps1` (PowerShell) or `windows-setup.sh` (WSL2/bash)
- **Task scripts**: `task_fetch_bookings_windows.{ps1,sh}`, `task_backup_windows.{ps1,sh}`
- **Scheduled via**: Windows Task Scheduler (registered by `windows-setup.ps1`) or WSL2 crontab
- **Metabase seed**: `metabase/metabase_app_backup.sql.gz` (git-ignored; restored by the setup script if present)

## Environment Setup

### Prerequisites
1. Copy `.env.example` to `.env` and configure with actual API credentials:
   - `AWAIO_CLIENT_ID` and `AWAIO_CLIENT_SECRET` are required for API access
   - Database credentials default to development values

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   # Or with --break-system-packages on macOS if needed
   ```

### Docker Environment
Start the complete stack (PostgreSQL + Metabase by default):
```bash
docker compose up -d
docker compose ps  # Verify all containers are running
```

Access points:
- PostgreSQL: `localhost:5433` (credentials from .env)
- Metabase: http://localhost:3000
- pgAdmin: http://localhost:5050 (only with `--profile admin` or `full`)
- MindsDB: http://localhost:47334 (only with `--profile ai` or `full`)
- Chat App: http://localhost:8501 (only with `--profile ai` or `full`)

**Important**: When connecting from Metabase/pgAdmin to PostgreSQL, use hostname `postgres` (not `localhost`) since they run in Docker network. Inside the Docker network the port is `5432`; the external port on the host is `5433`.

**Deployment profiles**:
- **Default** (no profile): PostgreSQL + Metabase (~3 GB RAM)
- **Admin** (`--profile admin`): + pgAdmin (~3.5 GB RAM)
- **AI** (`--profile ai`): + MindsDB + Chat (~5 GB RAM)
- **Full** (`--profile full`): All services (~6 GB RAM)
- **Tools** (`--profile tools`): adds the `fetcher` container for one-off jobs (e.g. `docker compose --profile tools run --rm fetcher python3 fetch_bookings.py --days 1`)

See `README.md` and `README_DOCKER.md` for complete setup instructions.

## Secrets Management

Secrets live in `.env` only; keep a copy in a password manager (in particular `ANONYMIZE_SALT`).

Never commit `.env` files — they are git-ignored.

## Data Import Scripts

### fetch_entities.py
Fetches all entities from Awaio API with hierarchical parent-child relationships.

```bash
# Basic usage (imports to database)
python3 fetch_entities.py

# With statistics and JSON export
python3 fetch_entities.py --stats --save-json
```

**Key architectural detail**: Entities have a 4-level hierarchy (building → floors → areas → desks/rooms/lockers). The script uses topological sorting (`_topological_sort()`) to ensure parents are imported before children, avoiding foreign key constraint violations.

### fetch_bookings.py
Fetches bookings from Awaio API with OData filtering support and automatic entity resolution.

```bash
# Fetch today's bookings
python3 fetch_bookings.py

# Fetch specific date range (uses OData $filter syntax)
python3 fetch_bookings.py --date 2025-06-01 --days 136 --stats

# Historical data
python3 fetch_bookings.py --date 2025-09-01 --days 30
```

**Date handling**: The `--date` argument accepts `YYYY-MM-DD` format. The script converts this to an OData overlap filter and sends `includeObsolete=true`, which Awaio requires for bookings that ended more than ~7 days ago:
```
$filter=end ge '2025-06-01T00:00:00.000Z' and start le '2025-10-15T23:59:59.999Z'
```
The API rejects `includeObsolete` windows longer than 92 days, so `get_bookings()` splits long ranges into 90-day windows and dedupes by id. Historical bookings come back with status `obsolete` and are stored as `reserved`; admin bookings longer than 12 h are stored as `blocked` so they stay out of utilisation statistics.

**Logging**: default output is summaries and errors; `--verbose` logs every imported object and the full HTTP exchanges (credentials redacted).

**Automatic entity resolution**: If bookings reference entities not in the database, the script automatically calls `fetch_entities.py` to fetch them from the API, then retries the booking import. This ensures bookings are never skipped due to missing entities.

### scheduler_loop.py
Long-running loop that runs inside the `awaio-scheduler` container (same image as `fetcher`, started by default `docker compose up -d`). Once per top-of-hour between 07:00 and 19:00 Europe/Stockholm it runs `fetch_entities.py`, `fetch_bookings.py` (rolling window via `logs/last_fetch.state`), and `REFRESH MATERIALIZED VIEW bi.v_hour_slots`. State is updated only when all three steps succeed. The wait between runs is checked against the wall clock in 60 s chunks, so host sleep does not stall it. Logs go to stdout (`docker compose logs scheduler`) and `logs/scheduler.log` (rotated daily, 14 day retention). Because it shares `logs/last_fetch.state` with `task_fetch_bookings_windows.ps1`, do **not** also schedule the PS1 task in Windows Task Scheduler when the scheduler container is active.

## Database Architecture

### Entity Hierarchy
The database schema supports a hierarchical structure for entities:
- **Level 0**: Building (e.g., "Stadshuset") - root entity with no parent
- **Level 1**: Floors (e.g., "Plan 1", "Plan 2", "Plan 3")
- **Level 2**: Areas/Zones (e.g., "Lockers 1-18", "Tillsammansytan")
- **Level 3**: Bookable resources (desks, rooms, lockers)

The `parent_id` foreign key in `entities` table enforces this relationship.

### Key Tables
- `entities`: Bookable resources with hierarchical relationships via `parent_id`
- `bookings`: Reservations linked to entities, users, and calendar events
- `booking_organizers` / `booking_participants`: Many-to-many relationships
- `users`, `communities`, `calendar_events`: Supporting reference data

### Useful Database Functions
```sql
-- Find available entities in time slot
SELECT * FROM find_available_entities('community_id', 'start_time', 'end_time', 'group_tag');

-- Check booking conflicts
SELECT * FROM check_booking_conflicts('entity_id', 'start_time', 'end_time', 'exclude_booking_id');

-- View active bookings
SELECT * FROM active_bookings;
```

## Privacy & Anonymization

### Model

When `ANONYMIZE_USERS=true`, the raw Awaio `user_id` is **never written to any
table**. It is replaced by

    anon_id = HMAC-SHA256(ANONYMIZE_SALT, awaio_user_id).hex()[:24]

and this `anon_id` becomes `users.id` plus every FK reference
(`bookings.owner_id`, `booking_organizers.user_id`, `booking_participants.user_id`).
`users.email` and `users.display_name` are derived from `anon_id`, not from the
raw user_id, so they leak nothing either.

### Properties

- **Stable over time**: same `awaio_user_id` + same salt → same `anon_id` in
  every import. Longitudinal analysis (one user's bookings across months)
  works exactly as before.
- **Irreversible without the salt**: given only a DB dump, reconstructing the
  Awaio user_id requires guessing the 256-bit salt — computationally
  infeasible.
- **Stateless**: there is no `user_anonymization_map` table. Hashing is
  deterministic, so no lookup table is needed (and no such table can leak).

### Salt handling

`ANONYMIZE_SALT` is **required** when `ANONYMIZE_USERS=true`; `fetch_bookings.py`
aborts at startup if it is missing. Generate once with `openssl rand -hex 32`,
store in `.env` and a password manager. **If the salt is lost, longitudinal
correlation between old and new imports is permanently broken** — there is no
way to recover the previous pseudonyms.

### What's anonymized, what isn't

- Anonymized: `users.id`, `users.email`, `users.display_name`,
  `bookings.owner_id`, `booking_organizers.user_id`, `booking_participants.user_id`.
- Never stored: `calendar_events.title`, `calendar_events.description`,
  `bookings.info` — these columns were dropped from the schema because they
  carry free text that can re-identify people (calendar event names, guest
  notes). If a future Awaio API version exposes additional free-text fields
  (`attendees`, `notes`, etc.), treat them the same way: drop or hash before
  persisting.

### Implementation

- `anonymize.py`: `hash_user_id(raw, salt)`, `DatabaseAnonymizer.identity_for()`.
- `fetch_bookings.py`: `BookingImporter._anon_id()` applies hashing at every
  write path; `main()` enforces the salt requirement.

## API Integration Notes

### Authentication
All API scripts use OAuth2 client credentials flow:
```python
{
    'client_id': CLIENT_ID,
    'client_secret': CLIENT_SECRET,
    'grant_type': 'client_credentials'
}
```

Token is obtained from `/auth/token` endpoint and used as Bearer token for subsequent requests.

### API Version
The API host is `https://api.awaio.com` (auth: `/auth/token`). The default base URL is `v1.0.0` for entities and `v1.1.0` for bookings (check `API_BASE_URL` in the scripts; docker-compose sets `v1.1.0` for both).

## Common Issues

### Photo Import
Photo import is intentionally disabled in `fetch_entities.py` because API returns dict objects instead of URL strings. The import methods exist but are not called.

### Entity Import Failures
If entity import fails with foreign key constraint errors, it means parent entities are not imported yet. The topological sort in `fetch_entities.py` handles this, but if manually inserting data, ensure parents exist first.

### Metabase Models
`metabase/models/*.sql` defines five semantic models (Entities With Hierarchy, Bookings Enriched, Daily Entity Metrics, User Weekly Mobility, Entity Sharing Metrics) that sit between the raw tables and the dashboard questions. The SQL lives in git; running `python3 scripts/create_metabase_models.py` creates or updates the corresponding cards in Metabase via the API (idempotent; needs `METABASE_API_KEY` in `.env`). Prefer building new saved questions on top of these models over hand-joining the raw tables.

### Metabase Queries
For Metabase visualizations:
- Use **Native Query (SQL)** to avoid "Other" grouping in results
- For Pivot Tables, query MUST have aggregation (COUNT, SUM, etc.) and GROUP BY
- When connecting to database from Metabase, use hostname `postgres` (Docker network name)

## Database Management

```bash
# Connect to PostgreSQL directly
docker compose exec postgres psql -U awaio_user -d awaio_db

# Backup database
docker compose exec postgres pg_dump -U awaio_user awaio_db > backup.sql

# Clear all entities and related data
docker compose exec -T postgres psql -U awaio_user -d awaio_db -c "TRUNCATE entities CASCADE;"

# View container logs
docker compose logs -f postgres
```

## Data Flow

1. **API** → `fetch_entities.py` → **PostgreSQL** (entities with hierarchy)
2. **API** → `fetch_bookings.py` → **PostgreSQL** (bookings with date filtering)
3. **PostgreSQL** → **Metabase** (visualization and analysis)
