# Awaio Docker Environment - Setup Guide

Docker-miljö för Awaio med PostgreSQL, Metabase och Python import-script.

## Komponenter

- **PostgreSQL 16**: Databas för bookings och entities
- **Metabase**: Visualisering och analys av data
- **pgAdmin**: Web-baserad databashantering
- **Python Import Script**: Import av JSON-data till PostgreSQL

## Snabbstart

### 1. Förberedelser

Skapa en `.env` fil baserad på `.env.example`:

```bash
cp .env.example .env
```

Redigera `.env` och anpassa värdena efter behov.

### 2. Starta Docker-miljön

```bash
# Starta alla services
docker-compose up -d

# Visa logs
docker-compose logs -f

# Kontrollera status
docker-compose ps
```

### 3. Verifiera att allt fungerar

- **PostgreSQL**: `localhost:5432`
- **Metabase**: http://localhost:3000
- **pgAdmin**: http://localhost:5050

## Importera JSON-data

### Installera Python-beroenden

```bash
# Skapa virtuell miljö
python3 -m venv venv
source venv/bin/activate  # På Windows: venv\Scripts\activate

# Installera dependencies
pip install psycopg2-binary python-dotenv
```

### Kör import-scriptet

```bash
# Importera bookings från JSON-fil
python import_bookings.py json/response_1760381039822.json

# Med statistik
python import_bookings.py json/response_1760381039822.json --stats
```

## Användning

### PostgreSQL

**Anslut från lokal dator:**

```bash
psql -h localhost -p 5432 -U awaio_user -d awaio_db
```

**Anslut från Python:**

```python
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

conn = psycopg2.connect(
    host=os.getenv('POSTGRES_HOST', 'localhost'),
    port=int(os.getenv('POSTGRES_PORT', 5432)),
    database=os.getenv('POSTGRES_DB', 'awaio_db'),
    user=os.getenv('POSTGRES_USER', 'awaio_user'),
    password=os.getenv('POSTGRES_PASSWORD', 'change_me')
)
```

### Metabase

1. Öppna http://localhost:3000
2. Första gången: skapa admin-användare
3. Lägg till PostgreSQL-databas:
   - **Database type**: PostgreSQL
   - **Host**: postgres
   - **Port**: 5432
   - **Database name**: awaio_db
   - **Username**: awaio_user
   - **Password**: (från .env)

### pgAdmin

1. Öppna http://localhost:5050
2. Logga in med credentials från `.env`:
   - Email: `admin@awaio.local`
   - Password: `admin`
3. Lägg till server:
   - **Host**: postgres
   - **Port**: 5432
   - **Username**: awaio_user
   - **Password**: (från .env)

## Databasschema

Databasen innehåller följande huvudtabeller:

- `communities` - Organisationer/communities
- `users` - Användare
- `entities` - Bokningsbara resurser (rum, skrivbord, etc.)
- `bookings` - Bokningar
- `booking_organizers` - Bokningens organisatörer
- `booking_participants` - Bokningens deltagare
- `calendar_events` - Kalenderevents

### Användbara queries

**Hämta aktiva bokningar:**
```sql
SELECT * FROM active_bookings;
```

**Hitta lediga resurser:**
```sql
SELECT * FROM find_available_entities(
    'OlnrwKaefGc2C2Z9Znzv',  -- community_id
    '2025-10-15 09:00:00',   -- start_time
    '2025-10-15 17:00:00',   -- end_time
    'desk'                    -- group_tag (optional)
);
```

**Kontrollera bokningskonflikter:**
```sql
SELECT * FROM check_booking_conflicts(
    'example-desk-1',  -- entity_id
    '2025-10-15 09:00:00',   -- start_time
    '2025-10-15 17:00:00',   -- end_time
    NULL                      -- exclude_booking_id (optional)
);
```

## Import Script Features

`import_bookings.py` scriptet hanterar automatiskt:

- Skapar communities, users, entities om de inte finns
- Importerar bookings med alla relaterade data
- Hanterar organizers och participants
- Undviker duplikater med UPSERT
- Visar progress under import
- Visar statistik efter import

## Hantera Docker-miljön

```bash
# Stoppa alla services
docker-compose down

# Stoppa och ta bort volumes (VARNING: raderar all data!)
docker-compose down -v

# Starta om en specifik service
docker-compose restart postgres

# Se logs för en specifik service
docker-compose logs -f postgres

# Öppna shell i container
docker-compose exec postgres psql -U awaio_user -d awaio_db
```

## Backup och Restore

### Backup

```bash
# Backup av hela databasen
docker-compose exec postgres pg_dump -U awaio_user awaio_db > backup.sql

# Backup med datum
docker-compose exec postgres pg_dump -U awaio_user awaio_db > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore

```bash
# Restore från backup
docker-compose exec -T postgres psql -U awaio_user awaio_db < backup.sql
```

## Felsökning

### PostgreSQL startar inte

```bash
# Kontrollera logs
docker-compose logs postgres

# Kontrollera att port 5432 inte används
lsof -i :5432  # På macOS/Linux
netstat -ano | findstr :5432  # På Windows
```

### Kan inte ansluta till databasen

1. Kontrollera att containern körs: `docker-compose ps`
2. Kontrollera credentials i `.env`
3. Om du ansluter inifrån Docker-nätverket, använd hostname `postgres` istället för `localhost`

### Import-script misslyckas

```bash
# Kontrollera att Python-beroenden är installerade
pip list | grep psycopg2

# Kontrollera att .env filen finns och innehåller rätt värden
cat .env

# Testa databasanslutningen
python -c "import psycopg2; from dotenv import load_dotenv; import os; load_dotenv(); print(psycopg2.connect(host='localhost', database='awaio_db', user='awaio_user', password=os.getenv('POSTGRES_PASSWORD')))"
```

## Produktionsdrift

För produktionsmiljö, överväg följande:

1. **Säkerhet:**
   - Använd starka lösenord
   - Aktivera SSL för databasanslutningar
   - Använd secrets management (t.ex. Docker secrets)
   - Begränsa nätverksåtkomst

2. **Backup:**
   - Automatisera backups med cron
   - Lagra backups på annan plats
   - Testa restore-procedur regelbundet

3. **Monitoring:**
   - Sätt upp monitoring av databas och services
   - Logga och övervaka felmeddelanden
   - Sätt upp alerts för viktiga events

4. **Performance:**
   - Justera PostgreSQL konfiguration för produktionslast
   - Överväg connection pooling (t.ex. PgBouncer)
   - Indexera tabeller baserat på användningsmönster

## Licens

Anpassa efter ditt projekts licens.
