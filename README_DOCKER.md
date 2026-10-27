# Awaio Docker Environment - Setup Guide

Docker environment for Awaio with PostgreSQL, Metabase and the Python import scripts.

## Components

- **PostgreSQL 16**: Database for bookings and entities
- **Metabase**: Visualisation and analysis of the data
- **pgAdmin**: Web-based database administration
- **Python import scripts**: Fetch data from the Awaio API into PostgreSQL

## Quick start

### 1. Preparation

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Edit `.env` and adjust the values as needed (at least the Awaio credentials and the passwords).

### 2. Start the Docker environment

```bash
# Start all default services
docker compose up -d

# Show logs
docker compose logs -f

# Check status
docker compose ps
```

### 3. Check that everything works

- **PostgreSQL**: `localhost:5433`
- **Metabase**: http://localhost:3000
- **pgAdmin**: http://localhost:5050 (with `--profile admin`)

## Importing data

The scheduler container fetches data every hour. To import manually:

```bash
# Entities (desks, rooms, lockers and their hierarchy)
docker compose --profile tools run --rm fetcher python3 fetch_entities.py --stats

# Bookings for a date range
docker compose --profile tools run --rm fetcher python3 fetch_bookings.py --date 2025-06-01 --days 30 --stats
```

To run the scripts outside Docker:

```bash
# Create a virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

python3 fetch_bookings.py --days 1 --stats
```

## Usage

### PostgreSQL

**Connect from your own machine:**

```bash
psql -h localhost -p 5433 -U awaio_user -d awaio_db
```

**Connect from Python:**

```python
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

conn = psycopg2.connect(
    host=os.getenv('POSTGRES_HOST', 'localhost'),
    port=int(os.getenv('POSTGRES_PORT', 5433)),
    database=os.getenv('POSTGRES_DB', 'awaio_db'),
    user=os.getenv('POSTGRES_USER', 'awaio_user'),
    password=os.getenv('POSTGRES_PASSWORD', 'change_me')
)
```

### Metabase

1. Open http://localhost:3000
2. First time: create an admin user
3. Add the PostgreSQL database:
   - **Database type**: PostgreSQL
   - **Host**: postgres
   - **Port**: 5432
   - **Database name**: awaio_db
   - **Username**: awaio_user
   - **Password**: (from .env)

### pgAdmin

1. Open http://localhost:5050
2. Log in with the credentials from `.env` (`PGADMIN_EMAIL` / `PGADMIN_PASSWORD`)
3. Add a server:
   - **Host**: postgres
   - **Port**: 5432
   - **Username**: awaio_user
   - **Password**: (from .env)

## Database schema

The database contains these main tables:

- `communities` - Organisations/communities
- `users` - Users (pseudonymised when `ANONYMIZE_USERS=true`)
- `entities` - Bookable resources (rooms, desks, etc.)
- `bookings` - Bookings
- `booking_organizers` - The booking's organisers
- `booking_participants` - The booking's participants
- `calendar_events` - Calendar events

### Useful queries

**Get active bookings:**
```sql
SELECT * FROM active_bookings;
```

**Find free resources:**
```sql
SELECT * FROM find_available_entities(
    'your-community-id',      -- community_id
    '2025-10-15 09:00:00',   -- start_time
    '2025-10-15 17:00:00',   -- end_time
    'desk'                    -- group_tag (optional)
);
```

**Check booking conflicts:**
```sql
SELECT * FROM check_booking_conflicts(
    'example-desk-1',  -- entity_id
    '2025-10-15 09:00:00',   -- start_time
    '2025-10-15 17:00:00',   -- end_time
    NULL                      -- exclude_booking_id (optional)
);
```

## Import script features

`fetch_bookings.py` automatically:

- Creates communities, users and calendar events if they do not exist
- Fetches missing entities via `fetch_entities.py`
- Imports bookings with all related data
- Handles organizers and participants
- Avoids duplicates with UPSERT
- Shows a summary and statistics after the import (`--verbose` for per-booking detail)

## Managing the Docker environment

```bash
# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes all data!)
docker compose down -v

# Restart a specific service
docker compose restart postgres

# Logs for a specific service
docker compose logs -f postgres

# Open a shell in the container
docker compose exec postgres psql -U awaio_user -d awaio_db
```

## Backup and restore

### Backup

```bash
# Back up the whole database
docker compose exec postgres pg_dump -U awaio_user awaio_db > backup.sql

# Backup with a timestamp
docker compose exec postgres pg_dump -U awaio_user awaio_db > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore

```bash
# Restore from a backup
docker compose exec -T postgres psql -U awaio_user awaio_db < backup.sql
```

## Troubleshooting

### PostgreSQL does not start

```bash
# Check the logs
docker compose logs postgres

# Check that port 5433 is not in use
lsof -i :5433  # On macOS/Linux
netstat -ano | findstr :5433  # On Windows
```

### Cannot connect to the database

1. Check that the container is running: `docker compose ps`
2. Check the credentials in `.env`
3. If you connect from inside the Docker network, use the hostname `postgres` instead of `localhost`

### The import script fails

```bash
# Check that the Python dependencies are installed
pip list | grep psycopg2

# Check that the .env file exists and has the right values
cat .env

# Test the database connection
python -c "import psycopg2; from dotenv import load_dotenv; import os; load_dotenv(); print(psycopg2.connect(host='localhost', port=5433, database='awaio_db', user='awaio_user', password=os.getenv('POSTGRES_PASSWORD')))"
```

## Production use

For a production environment, consider the following:

1. **Security:**
   - Use strong passwords
   - Enable SSL for database connections
   - Use secrets management (e.g. Docker secrets)
   - Restrict network access (bind ports to `127.0.0.1` unless they must be reachable)

2. **Backup:**
   - Automate backups with cron or Task Scheduler
   - Store backups somewhere else
   - Test the restore procedure regularly

3. **Monitoring:**
   - Set up monitoring of the database and services
   - Log and monitor error messages
   - Set up alerts for important events

4. **Performance:**
   - Tune the PostgreSQL configuration for production load
   - Consider connection pooling (e.g. PgBouncer)
   - Index tables based on usage patterns

## License

EUPL-1.2 — see [LICENSE](LICENSE).
