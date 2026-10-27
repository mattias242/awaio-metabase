# MindsDB Setup Guide for Awaio

MindsDB is integrated with the Awaio system to build predictive models and trend analyses based on the booking data.

## Access

- **HTTP API**: http://localhost:47334
- **MySQL API**: `localhost:47335`
- **MongoDB API**: `localhost:47336`
- **Web UI**: http://localhost:47334

## Quick start

### 1. Start MindsDB

```bash
# Start all services (including MindsDB)
docker-compose up -d

# Check that MindsDB is running
docker-compose ps mindsdb

# Show the MindsDB logs
docker-compose logs -f mindsdb
```

### 2. Connect to the PostgreSQL database

Run the following SQL in MindsDB (via the HTTP UI or a MySQL client):

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

### 3. Test the connection

```sql
-- Check the connection
SHOW DATABASES;

-- Test reading data
SELECT * FROM awaio_postgres.bookings LIMIT 5;
```

## Predictive models

### Model 1: booking forecast

Predict the number of bookings for the coming weeks based on historical data.

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

**Usage:**
```sql
-- Predict the next 14 days
SELECT
  booking_date,
  day_of_week,
  booking_count as predicted_bookings
FROM booking_forecaster
WHERE booking_date > CURRENT_DATE
ORDER BY booking_date
LIMIT 14;
```

### Model 2: desk popularity

Predict which desks will be the most popular next week.

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

**Usage:**
```sql
-- See the predictions for next week
SELECT
  desk_name,
  weekly_bookings as predicted_bookings,
  unique_users as predicted_unique_users
FROM desk_popularity_predictor
WHERE week_start = DATE_TRUNC('week', CURRENT_DATE + INTERVAL '7 days')
ORDER BY predicted_bookings DESC
LIMIT 10;
```

### Model 3: hourly capacity utilisation

Predict how many desks will be in use per hour.

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

**Usage:**
```sql
-- See the capacity for tomorrow
SELECT
  time_slot,
  hour_of_day,
  desks_in_use as predicted_desks_in_use,
  ROUND((desks_in_use::numeric / 57 * 100), 1) as utilization_percentage
FROM hourly_capacity_predictor
WHERE time_slot::date = CURRENT_DATE + INTERVAL '1 day'
ORDER BY hour_of_day;
```

### Model 4: user preferences

Predict which desk a user is likely to choose.

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

**Usage:**
```sql
-- Recommend desks for a specific user
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

### Model 5: cancellation prediction

Predict the probability that a booking will be cancelled.

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

**Usage:**
```sql
-- Predict the cancellation risk for upcoming bookings
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

## Managing models

```sql
-- List all models
SHOW MODELS;

-- See the details of a model
DESCRIBE booking_forecaster;

-- Delete a model
DROP MODEL booking_forecaster;

-- Retrain a model (when there is new data)
RETRAIN booking_forecaster;
```

## Using MindsDB via a MySQL client

```bash
# Connect to MindsDB via the MySQL protocol
mysql -h 127.0.0.1 -P 47335 -u mindsdb -p

# Or via Docker
docker exec -it awaio-mindsdb mysql -h 127.0.0.1 -P 47335 -u mindsdb
```

## Using the MindsDB HTTP API

```bash
# Run SQL via the HTTP API
curl -X POST http://localhost:47334/api/sql/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT * FROM booking_forecaster WHERE booking_date > CURRENT_DATE LIMIT 10"
  }'
```

## Integration with Metabase

You can show MindsDB predictions in Metabase by:

1. Creating a VIEW in PostgreSQL that fetches predictions from MindsDB
2. Using a Metabase Native Query to run SQL against MindsDB
3. Scheduling predictions and saving them to a PostgreSQL table

### Example: create a VIEW for predictions

```sql
-- Run in PostgreSQL (via pgAdmin or psql)
CREATE OR REPLACE VIEW booking_predictions AS
SELECT
  CURRENT_DATE + (n || ' days')::interval as prediction_date,
  EXTRACT(DOW FROM CURRENT_DATE + (n || ' days')::interval) as day_of_week,
  -- This is a placeholder; the actual predictions must be fetched from MindsDB
  0 as predicted_bookings
FROM generate_series(1, 14) n;
```

## Troubleshooting

### MindsDB does not start
```bash
# Check the logs
docker-compose logs mindsdb

# Restart MindsDB
docker-compose restart mindsdb
```

### Cannot connect to PostgreSQL from MindsDB
- Check that both services are on the same Docker network (`awaio-network`)
- Use the hostname `postgres` (not `localhost`) in the connection string
- Verify the PostgreSQL credentials in `.env`

### The model trains slowly
- MindsDB needs enough historical data (at least 30-90 days is recommended)
- The first training can take several minutes depending on the amount of data
- Use `LIMIT` in the training data for faster prototyping

### The predictions are wrong
- Check that there is enough training data
- Make sure the data types are correct (use `::int`, `::numeric` etc.)
- Try different `engine` options: `lightwood`, `statsforecast`, `neuralforecast`

## Next steps

1. ✅ Connect MindsDB to PostgreSQL
2. ✅ Create your first model (start with `booking_forecaster`)
3. ✅ Test the predictions
4. ✅ Integrate the predictions into Metabase dashboards
5. ✅ Set up scheduled retraining

See `setup_mindsdb.sql` to run all the initial setup automatically.
