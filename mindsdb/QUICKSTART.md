# MindsDB Quickstart - Awaio Predictions

## 🚀 Quick start (5 minutes)

### 1. Open the MindsDB Web UI
Open in your browser: **http://localhost:47334**

### 2. Connect to PostgreSQL
Copy and run [01_connect_postgres.sql](01_connect_postgres.sql) in the SQL Editor:

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

**Expected result:** "Query successfully completed"

### 3. Test the connection

**IMPORTANT:** the MindsDB Web UI only runs ONE query at a time!

Run each file separately:

**A. Show databases** - run [02a_show_databases.sql](02a_show_databases.sql):
```sql
SHOW DATABASES
```
**You should see:** `awaio_postgres` in the list

**B. Test reading bookings** - run [02b_test_bookings.sql](02b_test_bookings.sql):
```sql
SELECT * FROM awaio_postgres.bookings LIMIT 10
```
**You should see:** 10 bookings from your database

**C. Show tables** - run [02c_show_tables.sql](02c_show_tables.sql):
```sql
SHOW TABLES FROM awaio_postgres
```
**You should see:** bookings, entities, users, communities, etc.

**D. See statistics** - run [02d_booking_stats.sql](02d_booking_stats.sql):
```sql
SELECT
  COUNT(*) as total_bookings,
  COUNT(DISTINCT owner_id) as unique_users,
  COUNT(DISTINCT entity_id) as unique_entities,
  MIN(start_time) as earliest_booking,
  MAX(start_time) as latest_booking
FROM awaio_postgres.bookings
```

### 4. Create your first ML model
Run [03_first_prediction_model.sql](03_first_prediction_model.sql):

```sql
CREATE MODEL booking_forecast
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('day', start_time) as booking_date,
     EXTRACT(DOW FROM start_time) as day_of_week,
     COUNT(*) as booking_count
   FROM bookings
   WHERE start_time >= NOW() - INTERVAL '90 days'
     AND start_time < NOW()
   GROUP BY booking_date, day_of_week
   ORDER BY booking_date)
PREDICT booking_count
ORDER BY booking_date
USING
  engine = 'statsforecast',
  horizon = 14;
```

**NOTE:** this takes 2-5 minutes! Wait until it is finished.

### 5. Check the training status
```sql
DESCRIBE booking_forecast;
```

**Look for:** `STATUS: complete` or `STATUS: generating`

### 6. Use the predictions!
When the model is ready, run [04_use_predictions.sql](04_use_predictions.sql):

```sql
SELECT
  booking_date,
  CASE day_of_week
    WHEN 0 THEN 'Sunday'
    WHEN 1 THEN 'Monday'
    WHEN 2 THEN 'Tuesday'
    WHEN 3 THEN 'Wednesday'
    WHEN 4 THEN 'Thursday'
    WHEN 5 THEN 'Friday'
    WHEN 6 THEN 'Saturday'
  END as weekday,
  booking_count as predicted_bookings
FROM booking_forecast
WHERE booking_date > CURRENT_DATE
ORDER BY booking_date
LIMIT 14;
```

**Result:** booking forecasts for the next 14 days! 🎉

---

## 📊 More advanced models

Once you are done with the basics, try these:

### Hourly capacity prediction
```sql
CREATE MODEL hourly_capacity
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('hour', b.start_time) as time_slot,
     EXTRACT(DOW FROM b.start_time) as day_of_week,
     EXTRACT(HOUR FROM b.start_time) as hour_of_day,
     COUNT(DISTINCT b.entity_id) as desks_in_use
   FROM bookings b
   JOIN entities e ON b.entity_id = e.id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '60 days'
   GROUP BY time_slot, day_of_week, hour_of_day)
PREDICT desks_in_use
USING engine = 'lightwood';
```

### Usage:
```sql
-- Capacity tomorrow
SELECT
  time_slot,
  hour_of_day,
  desks_in_use as predicted_desks,
  ROUND((desks_in_use::numeric / 57 * 100), 1) as utilization_pct
FROM hourly_capacity
WHERE time_slot::date = CURRENT_DATE + INTERVAL '1 day'
ORDER BY hour_of_day;
```

### Popular desks next week
```sql
CREATE MODEL desk_popularity
FROM awaio_postgres
  (SELECT
     e.id as desk_id,
     e.name as desk_name,
     DATE_TRUNC('week', b.start_time) as week_start,
     COUNT(b.id) as weekly_bookings,
     COUNT(DISTINCT b.owner_id) as unique_users
   FROM entities e
   JOIN bookings b ON e.id = b.entity_id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '90 days'
   GROUP BY e.id, e.name, week_start)
PREDICT weekly_bookings
USING engine = 'lightwood';
```

### Usage:
```sql
-- Top 10 next week
SELECT
  desk_name,
  weekly_bookings as predicted_bookings
FROM desk_popularity
WHERE week_start = DATE_TRUNC('week', CURRENT_DATE + INTERVAL '7 days')
ORDER BY predicted_bookings DESC
LIMIT 10;
```

---

## 🔧 Troubleshooting

### "Connection failed"
- Check that PostgreSQL is running: `docker-compose ps postgres`
- Verify that both containers are on the same network

### "Model training failed"
- Check that you have enough data (at least 30 days is recommended)
- See the details: `DESCRIBE booking_forecast;`

### The model takes too long
- The first training can take 2-10 minutes depending on the amount of data
- Try a smaller dataset by shortening the INTERVAL window

### "Table not found"
- Double-check that `awaio_postgres` is the prefix: `awaio_postgres.bookings`
- List the tables: `SHOW TABLES FROM awaio_postgres;`

---

## 📚 Next steps

1. ✅ Create more models (see README.md)
2. ✅ Integrate the predictions into Metabase
3. ✅ Set up automatic retraining
4. ✅ Export predictions to PostgreSQL for visualisation

See [README.md](README.md) for the full documentation and all available models.
