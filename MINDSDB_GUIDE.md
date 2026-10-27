# MindsDB Guide för Awaio

MindsDB är nu tillgänglig och kopplad till din PostgreSQL-databas. Du kan använda MindsDB för att skapa ML-modeller direkt från dina bokningsdata.

## Åtkomst

- **MindsDB Web UI**: http://localhost:47334
- **MySQL API**: localhost:47335
- **MongoDB API**: localhost:47336

## Ansluta till PostgreSQL

### Via Web UI (Rekommenderat)

1. Öppna http://localhost:47334
2. Klicka på "Add Database" eller kör följande SQL i MindsDB Editor:

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

3. Verifiera anslutningen:
```sql
SHOW DATABASES;
```

## Exempel: Prediktera bokningar

### 1. Skapa en ML-modell för att prediktera mest populära skrivbord

```sql
CREATE MODEL booking_predictor
FROM awaio_postgres (
    SELECT
        e.name as desk_name,
        e.group_tag,
        EXTRACT(DOW FROM b.start_time) as day_of_week,
        EXTRACT(HOUR FROM b.start_time) as hour_of_day,
        COUNT(*) as booking_count
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    WHERE e.group_tag = 'desk'
    GROUP BY e.name, e.group_tag, EXTRACT(DOW FROM b.start_time), EXTRACT(HOUR FROM b.start_time)
)
PREDICT booking_count
USING engine = 'lightwood';
```

### 2. Använd modellen för att förutsäga bokningar

```sql
SELECT desk_name, booking_count
FROM booking_predictor
WHERE day_of_week = 1 AND hour_of_day = 9
ORDER BY booking_count DESC
LIMIT 10;
```

### 3. Tidsserie-modell för att förutsäga framtida bokningar

```sql
CREATE MODEL booking_forecast
FROM awaio_postgres (
    SELECT
        DATE(start_time) as booking_date,
        COUNT(*) as daily_bookings
    FROM bookings
    GROUP BY DATE(start_time)
    ORDER BY DATE(start_time)
)
PREDICT daily_bookings
ORDER BY booking_date
WINDOW 7
HORIZON 14
USING engine = 'statsforecast';
```

### 4. Kör prediktion för nästa 14 dagar

```sql
SELECT booking_date, daily_bookings
FROM booking_forecast
WHERE booking_date > LATEST;
```

## Användbara queries

### Se alla skrivbord och deras bokningsfrekvens
```sql
SELECT * FROM awaio_postgres.entities WHERE group_tag = 'desk';
```

### Se alla bokningar
```sql
SELECT * FROM awaio_postgres.bookings LIMIT 100;
```

### Kontrollera modellstatus
```sql
SHOW MODELS;
```

### Få information om en modell
```sql
DESCRIBE booking_predictor;
```

## Använd MindsDB via Python

```python
import mysql.connector

# Anslut till MindsDB via MySQL API
connection = mysql.connector.connect(
    host='localhost',
    port=47335,
    user='mindsdb',
    password=''
)

cursor = connection.cursor()

# Anslut till PostgreSQL via MindsDB
cursor.execute("""
    CREATE DATABASE awaio_postgres
    WITH ENGINE = 'postgres',
    PARAMETERS = {
        "host": "postgres",
        "port": 5432,
        "database": "awaio_db",
        "user": "awaio_user",
        "password": "change_me"
    };
""")

# Skapa en ML-modell
cursor.execute("""
    CREATE MODEL booking_predictor
    FROM awaio_postgres (
        SELECT entity_id, start_time, end_time, status
        FROM bookings
    )
    PREDICT status;
""")

# Använd modellen
cursor.execute("""
    SELECT entity_id, status, status_confidence
    FROM booking_predictor
    WHERE start_time = '2025-11-10 09:00:00';
""")

results = cursor.fetchall()
for row in results:
    print(row)

cursor.close()
connection.close()
```

## Avancerade användningsfall

### 1. Anomali-detektion
Identifiera ovanliga bokningsmönster:

```sql
CREATE ANOMALY DETECTOR booking_anomalies
FROM awaio_postgres (
    SELECT
        entity_id,
        EXTRACT(HOUR FROM start_time) as hour,
        EXTRACT(DOW FROM start_time) as day_of_week,
        (EXTRACT(EPOCH FROM (end_time - start_time))/3600)::int as duration_hours
    FROM bookings
)
USING engine = 'anomaly';
```

### 2. Klassificera bokningstyper
```sql
CREATE MODEL booking_classifier
FROM awaio_postgres (
    SELECT
        (EXTRACT(EPOCH FROM (end_time - start_time))/3600)::int as duration_hours,
        EXTRACT(DOW FROM start_time) as day_of_week,
        EXTRACT(HOUR FROM start_time) as hour,
        category
    FROM bookings
)
PREDICT category;
```

### 3. Rekommendationssystem för skrivbord
```sql
CREATE MODEL desk_recommender
FROM awaio_postgres (
    SELECT
        b.owner_id,
        e.name as desk_name,
        COUNT(*) as usage_count
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    WHERE e.group_tag = 'desk'
    GROUP BY b.owner_id, e.name
)
PREDICT desk_name
USING engine = 'lightwood';
```

## Felsökning

### Kontrollera att MindsDB körs
```bash
docker ps | grep mindsdb
```

### Se MindsDB-loggar
```bash
docker logs awaio-mindsdb
```

### Starta om MindsDB
```bash
docker-compose restart mindsdb
```

## Resurser

- [MindsDB Documentation](https://docs.mindsdb.com/)
- [MindsDB SQL Syntax](https://docs.mindsdb.com/sql/overview)
- [Time Series Forecasting](https://docs.mindsdb.com/sql/tutorials/time-series-forecasting)
- [Classification](https://docs.mindsdb.com/sql/tutorials/classification)
