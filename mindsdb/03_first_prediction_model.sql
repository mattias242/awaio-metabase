-- Step 3: Create your first prediction model
-- This model predicts the number of bookings per day
-- NOTE: For open source MindsDB, use the lightwood engine (default)

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

-- NOTE: This can take 2-5 minutes the first time!
-- You can check the status with: DESCRIBE booking_forecast;
