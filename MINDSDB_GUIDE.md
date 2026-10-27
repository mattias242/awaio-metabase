# MindsDB Guide for Awaio

MindsDB is available and connected to your PostgreSQL database. You can use MindsDB to create ML models directly from your booking data.

## Access

- **MindsDB Web UI**: http://localhost:47334
- **MySQL API**: localhost:47335
- **MongoDB API**: localhost:47336

## Connecting to PostgreSQL

### Via the Web UI (recommended)

1. Open http://localhost:47334
2. Click "Add Database" or run the following SQL in the MindsDB Editor:

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

3. Verify the connection:
```sql
SHOW DATABASES;
```

## Example: predicting bookings

### 1. Create an ML model that predicts the most popular desks

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

### 2. Use the model to predict bookings

```sql
SELECT desk_name, booking_count
FROM booking_predictor
WHERE day_of_week = 1 AND hour_of_day = 9
ORDER BY booking_count DESC
LIMIT 10;
```

### 3. Time series model to predict future bookings

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

### 4. Run a prediction for the next 14 days

```sql
SELECT booking_date, daily_bookings
FROM booking_forecast
WHERE booking_date > LATEST;
```

## Useful queries

### See all desks
```sql
SELECT * FROM awaio_postgres.entities WHERE group_tag = 'desk';
```

### See all bookings
```sql
SELECT * FROM awaio_postgres.bookings LIMIT 100;
```

### Check the model status
```sql
SHOW MODELS;
```

### Get information about a model
```sql
DESCRIBE booking_predictor;
```

## Using MindsDB from Python

```python
import mysql.connector

# Connect to MindsDB via the MySQL API
connection = mysql.connector.connect(
    host='localhost',
    port=47335,
    user='mindsdb',
    password=''
)

cursor = connection.cursor()

# Connect to PostgreSQL via MindsDB
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

# Create an ML model
cursor.execute("""
    CREATE MODEL booking_predictor
    FROM awaio_postgres (
        SELECT entity_id, start_time, end_time, status
        FROM bookings
    )
    PREDICT status;
""")

# Use the model
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

## Advanced use cases

### 1. Anomaly detection
Identify unusual booking patterns:

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

### 2. Classify booking types
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

### 3. Desk recommendation system
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

## Troubleshooting

### Check that MindsDB is running
```bash
docker ps | grep mindsdb
```

### See the MindsDB logs
```bash
docker logs awaio-mindsdb
```

### Restart MindsDB
```bash
docker-compose restart mindsdb
```

## Resources

- [MindsDB Documentation](https://docs.mindsdb.com/)
- [MindsDB SQL Syntax](https://docs.mindsdb.com/sql/overview)
- [Time Series Forecasting](https://docs.mindsdb.com/sql/tutorials/time-series-forecasting)
- [Classification](https://docs.mindsdb.com/sql/tutorials/classification)
