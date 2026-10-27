# MindsDB Setup Guide för Awaio

MindsDB är integrerat med Awaio-systemet för att skapa prediktiva modeller och trendanalyser baserade på bokningsdata.

## Tillgång

- **HTTP API**: http://localhost:47334
- **MySQL API**: `localhost:47335`
- **MongoDB API**: `localhost:47336`
- **Web UI**: http://localhost:47334

## Snabbstart

### 1. Starta MindsDB

```bash
# Starta alla services (inklusive MindsDB)
docker-compose up -d

# Kontrollera att MindsDB är igång
docker-compose ps mindsdb

# Se MindsDB-loggar
docker-compose logs -f mindsdb
```

### 2. Anslut till PostgreSQL-databasen

Kör följande SQL i MindsDB (via HTTP UI eller MySQL client):

```sql
CREATE DATABASE awaio_postgres
WITH ENGINE = 'postgres',
PARAMETERS = {
  "host": "postgres",
  "port": 5432,
  "database": "awaio_db",
  "user": "awaio_user",
  "password": "change_me"
};
```

### 3. Testa anslutningen

```sql
-- Kontrollera anslutningen
SHOW DATABASES;

-- Testa att läsa data
SELECT * FROM awaio_postgres.bookings LIMIT 5;
```

## Prediktiva Modeller

### Modell 1: Bokningsprognos

Predicera antalet bokningar för kommande veckor baserat på historisk data.

```sql
CREATE MODEL booking_forecaster
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('day', start_time)::date as booking_date,
     EXTRACT(DOW FROM start_time)::int as day_of_week,
     EXTRACT(WEEK FROM start_time)::int as week_number,
     COUNT(*)::int as booking_count
   FROM bookings
   WHERE start_time >= NOW() - INTERVAL '90 days'
     AND start_time < NOW()
   GROUP BY booking_date, day_of_week, week_number
   ORDER BY booking_date)
PREDICT booking_count
ORDER BY booking_date
USING
  engine = 'statsforecast',
  horizon = 14;
```

**Användning:**
```sql
-- Predicera nästa 14 dagar
SELECT
  booking_date,
  day_of_week,
  booking_count as predicted_bookings
FROM booking_forecaster
WHERE booking_date > CURRENT_DATE
ORDER BY booking_date
LIMIT 14;
```

### Modell 2: Skrivbordspopularitet

Predicera vilka skrivbord som kommer vara mest populära nästa vecka.

```sql
CREATE MODEL desk_popularity_predictor
FROM awaio_postgres
  (SELECT
     e.id as desk_id,
     e.name as desk_name,
     DATE_TRUNC('week', b.start_time)::date as week_start,
     COUNT(b.id)::int as weekly_bookings,
     COUNT(DISTINCT b.owner_id)::int as unique_users,
     ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) as avg_hours
   FROM entities e
   JOIN bookings b ON e.id = b.entity_id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '90 days'
   GROUP BY e.id, e.name, week_start
   ORDER BY week_start, desk_id)
PREDICT weekly_bookings
ORDER BY desk_id, week_start
USING
  engine = 'lightwood';
```

**Användning:**
```sql
-- Se predictions för nästa vecka
SELECT
  desk_name,
  weekly_bookings as predicted_bookings,
  unique_users as predicted_unique_users
FROM desk_popularity_predictor
WHERE week_start = DATE_TRUNC('week', CURRENT_DATE + INTERVAL '7 days')
ORDER BY predicted_bookings DESC
LIMIT 10;
```

### Modell 3: Kapacitetsutnyttjande per timme

Predicera hur många skrivbord som kommer användas per timme.

```sql
CREATE MODEL hourly_capacity_predictor
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('hour', b.start_time)::timestamp as time_slot,
     EXTRACT(DOW FROM b.start_time)::int as day_of_week,
     EXTRACT(HOUR FROM b.start_time)::int as hour_of_day,
     COUNT(DISTINCT b.entity_id)::int as desks_in_use
   FROM bookings b
   JOIN entities e ON b.entity_id = e.id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '60 days'
   GROUP BY time_slot, day_of_week, hour_of_day
   ORDER BY time_slot)
PREDICT desks_in_use
ORDER BY time_slot
USING
  engine = 'lightwood';
```

**Användning:**
```sql
-- Se kapacitet för imorgon
SELECT
  time_slot,
  hour_of_day,
  desks_in_use as predicted_desks_in_use,
  ROUND((desks_in_use::numeric / 57 * 100), 1) as utilization_percentage
FROM hourly_capacity_predictor
WHERE time_slot::date = CURRENT_DATE + INTERVAL '1 day'
ORDER BY hour_of_day;
```

### Modell 4: Användarpreferenser

Predicera vilket skrivbord en användare troligen kommer välja.

```sql
CREATE MODEL user_desk_preference_predictor
FROM awaio_postgres
  (SELECT
     b.owner_id,
     e.id as desk_id,
     e.name as desk_name,
     parent.name as area_name,
     EXTRACT(DOW FROM b.start_time)::int as day_of_week,
     EXTRACT(HOUR FROM b.start_time)::int as hour_of_day,
     COUNT(*)::int as booking_frequency
   FROM bookings b
   JOIN entities e ON b.entity_id = e.id
   LEFT JOIN entities parent ON e.parent_id = parent.id
   WHERE e.group_tag = 'desk'
   GROUP BY b.owner_id, e.id, e.name, parent.name, day_of_week, hour_of_day)
PREDICT desk_id
USING
  engine = 'lightwood';
```

**Användning:**
```sql
-- Rekommendera skrivbord för en specifik användare
SELECT
  desk_name,
  area_name,
  booking_frequency
FROM user_desk_preference_predictor
WHERE owner_id = 'USER_ID_HERE'
  AND day_of_week = EXTRACT(DOW FROM CURRENT_DATE)
  AND hour_of_day = 9
ORDER BY booking_frequency DESC
LIMIT 5;
```

### Modell 5: Avbokningsprediktion

Predicera sannolikhet för att en bokning kommer avbokas.

```sql
CREATE MODEL cancellation_predictor
FROM awaio_postgres
  (SELECT
     EXTRACT(EPOCH FROM (b.start_time - b.created_at)) / 3600 as hours_before_booking,
     EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 as booking_duration_hours,
     EXTRACT(DOW FROM b.start_time)::int as day_of_week,
     EXTRACT(HOUR FROM b.start_time)::int as hour_of_day,
     e.group_tag as entity_type,
     CASE WHEN b.cancelled THEN 1 ELSE 0 END as is_cancelled
   FROM bookings b
   JOIN entities e ON b.entity_id = e.id
   WHERE b.created_at >= NOW() - INTERVAL '180 days')
PREDICT is_cancelled
USING
  engine = 'lightwood';
```

**Användning:**
```sql
-- Predicera avbokningsrisk för kommande bokningar
SELECT
  b.id as booking_id,
  e.name as entity_name,
  b.start_time,
  p.is_cancelled as cancellation_probability
FROM awaio_postgres.bookings b
JOIN awaio_postgres.entities e ON b.entity_id = e.id
JOIN cancellation_predictor p
WHERE b.start_time > NOW()
  AND b.start_time < NOW() + INTERVAL '7 days'
  AND p.is_cancelled > 0.5
ORDER BY p.is_cancelled DESC;
```

## Hantera Modeller

```sql
-- Lista alla modeller
SHOW MODELS;

-- Se detaljer om en modell
DESCRIBE booking_forecaster;

-- Ta bort en modell
DROP MODEL booking_forecaster;

-- Retrain en modell (om ny data finns)
RETRAIN booking_forecaster;
```

## Använda MindsDB via MySQL Client

```bash
# Anslut till MindsDB via MySQL-protokollet
mysql -h 127.0.0.1 -P 47335 -u mindsdb -p

# Eller via Docker
docker exec -it awaio-mindsdb mysql -h 127.0.0.1 -P 47335 -u mindsdb
```

## Använda MindsDB HTTP API

```bash
# Kör SQL via HTTP API
curl -X POST http://localhost:47334/api/sql/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT * FROM booking_forecaster WHERE booking_date > CURRENT_DATE LIMIT 10"
  }'
```

## Integration med Metabase

Du kan visa MindsDB predictions i Metabase genom att:

1. Skapa en VIEW i PostgreSQL som hämtar predictions från MindsDB
2. Använda Metabase Native Query för att köra SQL mot MindsDB
3. Schemalägga predictions och spara till PostgreSQL-tabell

### Exempel: Skapa VIEW för predictions

```sql
-- Kör i PostgreSQL (via pgAdmin eller psql)
CREATE OR REPLACE VIEW booking_predictions AS
SELECT
  CURRENT_DATE + (n || ' days')::interval as prediction_date,
  EXTRACT(DOW FROM CURRENT_DATE + (n || ' days')::interval) as day_of_week,
  -- Detta är en placeholder, faktiska predictions måste hämtas från MindsDB
  0 as predicted_bookings
FROM generate_series(1, 14) n;
```

## Troubleshooting

### MindsDB startar inte
```bash
# Kontrollera loggar
docker-compose logs mindsdb

# Starta om MindsDB
docker-compose restart mindsdb
```

### Kan inte ansluta till PostgreSQL från MindsDB
- Kontrollera att båda services är på samma Docker-nätverk (`awaio-network`)
- Använd hostname `postgres` (inte `localhost`) i anslutningssträngen
- Verifiera PostgreSQL credentials i `.env`

### Modellen tränar långsamt
- MindsDB behöver tillräckligt med historisk data (minst 30-90 dagar rekommenderas)
- Första träningen kan ta flera minuter beroende på datamängd
- Använd `LIMIT` i träningsdata för snabbare prototyping

### Predictions är felaktiga
- Kontrollera att tillräckligt med träningsdata finns
- Se till att datatyperna är korrekta (använd `::int`, `::numeric` etc.)
- Prova olika `engine`-alternativ: `lightwood`, `statsforecast`, `neuralforecast`

## Nästa Steg

1. ✅ Anslut MindsDB till PostgreSQL
2. ✅ Skapa din första modell (börja med `booking_forecaster`)
3. ✅ Testa predictions
4. ✅ Integrera predictions i Metabase dashboards
5. ✅ Sätt upp scheduled retraining

Se `setup_mindsdb.sql` för att köra all initial setup automatiskt.
