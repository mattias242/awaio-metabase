# Awaio Booking Analytics — Windows 11 Docker Deployment

This project imports booking and entity data from the [Awaio](https://awaio.com) API into PostgreSQL and analyses it in Metabase. Awaio is a booking system for desks, rooms and lockers.

The repository is set up for a **local deployment on Windows 11 with Docker Desktop** (native PowerShell or WSL2).

---

## 📊 System overview

### Components

| Service | Port | Profile | Description |
|---------|------|---------|-------------|
| **PostgreSQL 16** | `localhost:5433` | default | Database for bookings and entities |
| **Metabase** | http://localhost:3000 | default | BI and dashboards |
| **pgAdmin** | http://localhost:5050 | `admin` / `full` | Database administration in the browser |
| **MindsDB** | http://localhost:47334 | `ai` / `full` | ML/AI predictions |
| **Chat App** | http://localhost:8501 | `ai` / `full` | Streamlit chat against MindsDB |
| **Scheduler** | — | default | Long-running loop: fetches entities and bookings and refreshes `bi.v_hour_slots` every full hour 07–19 Europe/Stockholm |
| **Fetcher** | — | `tools` | Same image as the scheduler — run ad hoc for historical imports (`docker compose --profile tools run --rm fetcher ...`) |

### Profiles (choose with `docker compose up`)

- **Default** (no profile): PostgreSQL + Metabase + Scheduler — ~3 GB RAM
- `--profile admin`: + pgAdmin — ~3.5 GB RAM
- `--profile ai`: + MindsDB + Chat — ~5 GB RAM
- `--profile full`: all services — ~6 GB RAM
- `--profile tools`: adds `fetcher` (run ad hoc with `run --rm`)

---

## 🚀 Quick start

### Prerequisites

- Windows 11 with [Docker Desktop](https://www.docker.com/products/docker-desktop/) (v3.4.0+, Compose v2)
- PowerShell 5.1+ (for the native Windows setup) or WSL2 with bash (for the WSL setup)
- ~6 GB free RAM if you want to run the `full` profile
- Ports `5433` and `3000` free

### Setup via PowerShell (recommended)

```powershell
# Run as administrator if you want to register scheduled tasks
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\windows-setup.ps1
```

The script:
1. Checks Docker, ports and RAM
2. Copies `.env.example` → `.env` (update it with your API credentials!)
3. Asks for a profile (Minimal / Admin / AI / Full)
4. Starts the containers
5. Restores `metabase/metabase_app_backup.sql.gz` if it exists
6. Registers a Windows Task Scheduler job for daily backups at 02:00 (hourly data fetching is handled by the `awaio-scheduler` container)

### Setup via WSL2/bash

```bash
chmod +x windows-setup.sh
./windows-setup.sh
```

Same steps as the PowerShell version, but it sets up crontab instead of Task Scheduler.

### Manual start

```bash
cp .env.example .env
# Edit .env and set AWAIO_CLIENT_ID / AWAIO_CLIENT_SECRET (and change the passwords)

docker compose up -d                    # default profile
docker compose --profile full up -d     # all services
```

---

## ⚙️ Automatic jobs

### Scheduler container (`awaio-scheduler`)

A long-running container that starts automatically with the default profile. The loop runs once per full hour **07:00–19:00 Europe/Stockholm** and does, in order:

1. `fetch_entities.py --stats`
2. `fetch_bookings.py --date (last_fetch - 1d) --days N` — rolling window with a 24 h buffer
3. `REFRESH MATERIALIZED VIEW bi.v_hour_slots`

The date of the last successful run is stored in `logs/last_fetch.state`. The file is updated **only** if all three steps succeed. Logs go to stdout (`docker compose logs -f scheduler`) and `logs/scheduler.log` (rotated at midnight, 14 days retention). By default the fetch scripts log summaries and errors only; pass `--verbose` for per-object detail. Source: `scheduler_loop.py`.

### Windows Task Scheduler (registered by `windows-setup.ps1`)

| Task | Schedule | Script |
|------|----------|--------|
| **Awaio - Daily Backup** | Daily 02:00 | `task_backup_windows.ps1` |

`task_fetch_bookings_windows.{ps1,sh}` remain for **manual** ad hoc runs and should **not** be scheduled in Task Scheduler while the `awaio-scheduler` container is active — both share `logs/last_fetch.state` and would collide.

### WSL2 crontab (alternative)

```bash
# Registered automatically by windows-setup.sh if you choose it:
0 2 * * * cd /path/to/awaio && bash task_backup_windows.sh
```

Backups end up in `./backups/` (7 days retention). Logs in `./logs/`.

---

## 🔧 Common commands

### Start/stop

```bash
docker compose up -d           # Start
docker compose down            # Stop (volumes are kept)
docker compose ps              # Container status
docker compose logs -f metabase
```

### Manual data fetching

> The ongoing hourly fetch is handled by the `awaio-scheduler` container (see [Automatic jobs](#️-automatic-jobs)). Use the commands below for historical imports or troubleshooting.

```powershell
# Recommended: the wrapper script works out the date range with a 24 h buffer
.\task_fetch_bookings_windows.ps1
```

```bash
# WSL2/bash equivalent
bash task_fetch_bookings_windows.sh
```

Directly against the fetcher container if you want to control the range yourself:
```bash
# Last 24 hours
docker compose --profile tools run --rm fetcher \
  python3 fetch_bookings.py --days 1 --stats

# Specific date range
docker compose --profile tools run --rm fetcher \
  python3 fetch_bookings.py --date 2025-06-01 --days 30 --stats

# Update entities (rarely needed — only when new resources are added)
docker compose --profile tools run --rm fetcher \
  python3 fetch_entities.py --stats
```

Historical bookings are fetched with `includeObsolete=true`; long ranges are split into windows of at most 90 days automatically (the Awaio API rejects more than 92 days).

### Database access

```bash
# PostgreSQL shell
docker compose exec postgres psql -U awaio_user -d awaio_db

# Manual backup
docker compose exec -T postgres pg_dump -U awaio_user awaio_db | gzip > manual_backup.sql.gz

# Restore
gunzip -c manual_backup.sql.gz | docker compose exec -T postgres psql -U awaio_user -d awaio_db
```

### Running the backup/fetch tasks manually

```powershell
.\task_fetch_bookings_windows.ps1
.\task_backup_windows.ps1
```

```bash
bash task_fetch_bookings_windows.sh
bash task_backup_windows.sh
```

---

## 🔐 Security & privacy

### User anonymisation (GDPR)

Set in `.env`:
```
ANONYMIZE_USERS=true
ANONYMIZE_SALT=<your-secret-salt>   # openssl rand -hex 32
```

- Awaio user ids are replaced by HMAC-SHA256 pseudonyms keyed with the salt
- Email: `john.doe@company.com` → `user_abc123@anonymous.local`
- Name: `John Doe` → `User ABC123`
- Consistent: the same `user_id` and salt always give the same pseudonym
- Never rotate the salt without re-importing all data

See `CLAUDE.md` → "Privacy & Anonymization" for the technical details.

### Credentials

All secrets live in `.env`, which is git-ignored. Never commit `.env`, and keep a copy of it (in particular `ANONYMIZE_SALT`) in a password manager.

---

## 🐛 Troubleshooting

### Docker Desktop is not running
```
ERR Docker Desktop does not seem to be running
```
→ Start Docker Desktop, wait until it shows "Running", then run the script again. Enable "Start Docker Desktop when you log in" in the settings.

### Port 5433 or 3000 in use
```
Error response from daemon: ports are not available
```
→ Find the process: `Get-NetTCPConnection -LocalPort 5433` (PowerShell). Stop the conflicting process or change the ports in `.env` (`POSTGRES_PORT`, `METABASE_PORT`).

### PostgreSQL does not start
```bash
docker compose logs postgres --tail 100
docker compose restart postgres
```

### Metabase is not available
- Wait 2–3 minutes after the first start (initial DB migration)
- `docker compose ps metabase` — the healthcheck should become `healthy`
- `docker compose logs metabase --tail 100`

### The scheduler does not fetch
- `docker compose logs --tail 50 scheduler` — every iteration ends with `Iteration succeeded` or `Iteration failed`
- Log file: `logs/scheduler.log`
- Test manually: `.\task_fetch_bookings_windows.ps1`

### Backup fails
- Log file: `logs/backup_YYYYMMDD.log`
- Check that the `awaio-postgres` container is running: `docker ps | grep postgres`
- Disk space: Docker Desktop → Settings → Resources → Disk

---

## 📁 File structure

```
awaio/
├── .env.example                         # Template for environment variables
├── docker-compose.yml                   # Docker Compose (the only compose file)
├── Dockerfile                           # (webhook app)
├── Dockerfile.fetcher                   # Python fetcher image
├── awaio_database_schema_postgres.sql   # Database schema (init)
├── init-metabase-db.sh                  # Creates the metabase_app database
├── fetch_bookings.py                    # Fetch bookings from the Awaio API
├── fetch_entities.py                    # Fetch entities (hierarchical)
├── anonymize.py                         # User anonymisation
├── scheduler_loop.py                    # Hourly loop in the awaio-scheduler container
├── windows-setup.ps1 / .sh              # Interactive setup
├── task_fetch_bookings_windows.{ps1,sh} # Manual ad hoc fetch
├── task_backup_windows.{ps1,sh}         # Daily backup
├── metabase/                            # SQL questions + Metabase models
├── mindsdb/                             # ML setup (optional)
├── chat_app/                            # Streamlit chat (optional)
├── scripts/                             # CI/test scripts
├── tests/                               # pytest tests
├── logs/                                # Task logs (created on first run)
└── backups/                             # Database backups (created by task_backup)
```

---

## 📚 More documentation

- `CLAUDE.md` — development guide, API details, database architecture
- `README_DOCKER.md` — generic Docker reference
- `MINDSDB_GUIDE.md` / `CLAUDE_MINDSDB_SETUP.md` — ML setup (optional)
- `FETCH_BOOKINGS_IMPROVEMENTS.md` — history of improvements to the fetcher
- `CONTRIBUTING.md` — contribution guidelines

---

**Tip**: Keep regular backups somewhere safe (for example cloud storage) in addition to the local 7-day retention.

## License

Copyright © 2025–2026 Mattias Wahlberg.

Licensed under the [EUPL-1.2](LICENSE) (European Union Public Licence v. 1.2).
