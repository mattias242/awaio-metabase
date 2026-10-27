# Awaio Booking System — Windows 11 Docker Deployment

Awaio är ett booking- och entity-management-system som integrerar med Awaio API:et. Data hämtas från API:et (bokningar, entiteter) och lagras i PostgreSQL för analys i Metabase.

Det här repot är konfigurerat för en **lokal deploy på Windows 11 med Docker Desktop** (native PowerShell eller WSL2).

---

## 📊 Systemöversikt

### Komponenter

| Tjänst | Port | Profil | Beskrivning |
|--------|------|--------|-------------|
| **PostgreSQL 16** | `localhost:5433` | default | Databas för bookings och entities |
| **Metabase** | http://localhost:3000 | default | BI och dashboards |
| **pgAdmin** | http://localhost:5050 | `admin` / `full` | Databashantering i browser |
| **MindsDB** | http://localhost:47334 | `ai` / `full` | ML/AI-predictions |
| **Chat App** | http://localhost:8501 | `ai` / `full` | Streamlit-chatt mot MindsDB |
| **Scheduler** | — | default | Långkörande loop: hämtar bookings + entities och refreshar `bi.v_hour_slots` varje hel timme 07–19 Europe/Stockholm |
| **Fetcher** | — | `tools` | Samma image som Scheduler — körs ad-hoc för historiska imports (`docker compose --profile tools run --rm fetcher ...`) |

### Profiler (välj vid `docker compose up`)

- **Default** (ingen profil): PostgreSQL + Metabase + Scheduler — ~3 GB RAM
- `--profile admin`: + pgAdmin — ~3.5 GB RAM
- `--profile ai`: + MindsDB + Chat — ~5 GB RAM
- `--profile full`: alla tjänster — ~6 GB RAM
- `--profile tools`: lägger till `fetcher` (körs ad-hoc med `run --rm`)

---

## 🚀 Snabbstart

### Förutsättningar

- Windows 11 med [Docker Desktop](https://www.docker.com/products/docker-desktop/) (v3.4.0+, Compose v2)
- PowerShell 5.1+ (för native Windows-setup) eller WSL2 med bash (för WSL-setup)
- ~6 GB fritt RAM om du vill köra `full`-profilen
- Portarna `5433` och `3000` lediga

### Setup via PowerShell (rekommenderat)

```powershell
# Kör som administratör om du vill registrera schemalagda tasks
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\windows-setup.ps1
```

Scriptet:
1. Kontrollerar Docker, portar och RAM
2. Kopierar `.env.example` → `.env` (uppdatera med dina API-credentials!)
3. Frågar efter profil (Minimal / Admin / AI / Full)
4. Startar containers
5. Återställer `metabase/metabase_app_backup.sql.gz` om den finns
6. Registrerar Windows Task Scheduler-jobb för dagliga backups 02:00 (timvis datahämtning sköts av `awaio-scheduler`-containern)

### Setup via WSL2/bash

```bash
chmod +x windows-setup.sh
./windows-setup.sh
```

Samma steg som PowerShell-versionen men sätter upp crontab istället för Task Scheduler.

### Manuell start

```bash
cp .env.example .env
# Redigera .env och sätt AWAIO_CLIENT_ID / AWAIO_CLIENT_SECRET

docker compose up -d                    # default-profil
docker compose --profile full up -d     # alla tjänster
```

---

## ⚙️ Automatiska jobb

### Scheduler-container (`awaio-scheduler`)

Långkörande container som startar automatiskt med default-profilen. Loopen kör en gång per hel timme **07:00–19:00 Europe/Stockholm** och utför, i ordning:

1. `fetch_bookings.py --date (last_fetch - 1d) --days N` — rullande fönster med 24h buffer
2. `fetch_entities.py --stats`
3. `REFRESH MATERIALIZED VIEW bi.v_hour_slots`

Tiden för senaste lyckade körning lagras i `logs/last_fetch.state`. Filen uppdateras **endast** om alla tre stegen lyckas. Loggar går till stdout (`docker compose logs -f scheduler`) och `logs/scheduler.log` (rotation midnatt, 14 dagars retention). Källa: `scheduler_loop.py`.

### Windows Task Scheduler (registreras av `windows-setup.ps1`)

| Task | Schema | Script |
|------|--------|--------|
| **Awaio - Daily Backup** | Dagligen 02:00 | `task_backup_windows.ps1` |

`task_fetch_bookings_windows.{ps1,sh}` finns kvar för **manuell** ad-hoc-körning och ska **inte** schemaläggas i Task Scheduler så länge `awaio-scheduler`-containern är aktiv — båda delar `logs/last_fetch.state` och skulle kollidera.

### WSL2 crontab (alternativ)

```bash
# Registreras automatiskt av windows-setup.sh om du väljer det:
0 2 * * * cd /path/to/awaio && bash task_backup_windows.sh
```

Backups hamnar i `./backups/` (7 dagars retention). Loggar i `./logs/`.

---

## 🔧 Vanliga kommandon

### Start/stopp

```bash
docker compose up -d           # Starta
docker compose down            # Stoppa (volymer bevaras)
docker compose ps              # Container-status
docker compose logs -f metabase
```

### Manuell datahämtning

> Den löpande timvisa hämtningen sköts av `awaio-scheduler`-containern (se [Automatiska jobb](#️-automatiska-jobb)). Använd kommandona nedan för historiska imports eller felsökning.

```powershell
# Rekommenderat: wrapper-scriptet sköter datumintervall med 24h buffer automatiskt
.\task_fetch_bookings_windows.ps1
```

```bash
# WSL2/bash-motsvarighet
bash task_fetch_bookings_windows.sh
```

Direkt mot fetcher-containern om du vill styra intervall själv:
```bash
# Senaste dygnet
docker compose --profile tools run --rm fetcher \
  python3 fetch_bookings.py --days 1 --stats

# Specifikt datumintervall
docker compose --profile tools run --rm fetcher \
  python3 fetch_bookings.py --date 2025-06-01 --days 30 --stats

# Uppdatera entiteter (körs sällan — bara när nya resurser läggs till)
docker compose --profile tools run --rm fetcher \
  python3 fetch_entities.py --stats
```

### Databasåtkomst

```bash
# PostgreSQL-shell
docker compose exec postgres psql -U awaio_user -d awaio_db

# Manuell backup
docker compose exec -T postgres pg_dump -U awaio_user awaio_db | gzip > manual_backup.sql.gz

# Restore
gunzip -c manual_backup.sql.gz | docker compose exec -T postgres psql -U awaio_user -d awaio_db
```

### Manuell körning av backup/fetch-tasks

```powershell
.\task_fetch_bookings_windows.ps1
.\task_backup_windows.ps1
```

```bash
bash task_fetch_bookings_windows.sh
bash task_backup_windows.sh
```

---

## 🔐 Säkerhet & Integritet

### Användar-anonymisering (GDPR)

Sätt i `.env`:
```
ANONYMIZE_USERS=true
ANONYMIZE_SALT=<din-hemliga-salt>
```

- Email: `john.doe@company.com` → `user_abc123@anonymous.local`
- Namn: `John Doe` → `User ABC123`
- Konsistent: samma `user_id` ger alltid samma anonyma identitet
- Databas-backat: mappning lagras i `user_anonymization_map`-tabellen

Se `CLAUDE.md` → "Privacy & Anonymization" för tekniska detaljer.

### Credentials

Alla hemligheter lagras i `.env` (i globala `.gitignore`). Committa aldrig `.env`. Projekt-credentials finns i Bitwarden (item `dev/awaio`):
```bash
bw-env awaio
```

---

## 🐛 Felsökning

### Docker Desktop körs inte
```
ERR Docker Desktop verkar inte köra
```
→ Starta Docker Desktop, vänta tills valen visas "Running", kör scriptet igen. Aktivera "Start Docker Desktop when you log in" i inställningarna.

### Port 5433 eller 3000 upptagen
```
Error response from daemon: ports are not available
```
→ Hitta processen: `Get-NetTCPConnection -LocalPort 5433` (PowerShell). Stäng av konflikterande process eller ändra portarna i `.env` (`POSTGRES_PORT`, `METABASE_PORT`).

### PostgreSQL startar inte
```bash
docker compose logs postgres --tail 100
docker compose restart postgres
```

### Metabase är inte tillgänglig
- Vänta 2–3 min efter första start (initial DB-migration)
- `docker compose ps metabase` — healthcheck ska bli `healthy`
- `docker compose logs metabase --tail 100`

### Fetcher-tasken kör inte
- Windows Task Scheduler → hitta "Awaio - Fetch Bookings" → "Last Run Result"
- Loggfil: `logs/task_scheduler_YYYYMMDD.log`
- Testa manuellt: `.\task_fetch_bookings_windows.ps1`

### Backup misslyckas
- Loggfil: `logs/backup_YYYYMMDD.log`
- Kontrollera att `awaio-postgres`-containern körs: `docker ps | grep postgres`
- Diskutrymme: Docker Desktop → Settings → Resources → Disk

---

## 📁 Filstruktur

```
awaio/
├── .env.example                         # Template för miljövariabler
├── docker-compose.yml                   # Docker Compose (enda compose-filen)
├── Dockerfile                           # (webhook-app)
├── Dockerfile.fetcher                   # Python-fetcher image
├── awaio_database_schema_postgres.sql   # Databasschema (init)
├── init-metabase-db.sh                  # Skapar metabase_app-databasen
├── fetch_bookings.py                    # Hämta bokningar från Awaio API
├── fetch_entities.py                    # Hämta entiteter (hierarkisk)
├── anonymize.py                         # Användaranonymisering
├── scheduler_loop.py                    # Timvis loop i awaio-scheduler-containern
├── windows-setup.ps1 / .sh              # Interaktiv setup
├── task_fetch_bookings_windows.{ps1,sh} # Manuell ad-hoc hämtning
├── task_backup_windows.{ps1,sh}         # Daglig backup
├── metabase/                            # SQL-frågor + Metabase-seed
├── mindsdb/                             # ML-setup (valfritt)
├── chat_app/                            # Streamlit-chatt (valfritt)
├── scripts/                             # CI/test-scripts
├── tests/                               # pytest-tester
├── logs/                                # Task-loggar (skapas vid första körning)
└── backups/                             # Databas-backups (skapas av task_backup)
```

---

## 📚 Mer dokumentation

- `CLAUDE.md` — utvecklings-guide, API-detaljer, databasarkitektur
- `README_DOCKER.md` — generisk Docker-referens
- `MINDSDB_GUIDE.md` / `CLAUDE_MINDSDB_SETUP.md` — ML-setup (valfri)
- `FETCH_BOOKINGS_IMPROVEMENTS.md` — historik över förbättringar i fetcher
- `CONTRIBUTING.md` — bidragsriktlinjer

---

**Tips**: Spara regelbundna backups på säker plats (t.ex. molnlagring) utöver den lokala 7-dagars-retentionen.

## Licens

Copyright © 2025–2026 Mattias Wahlberg.

Licensierad under [EUPL-1.2](LICENSE) (European Union Public Licence v. 1.2).
