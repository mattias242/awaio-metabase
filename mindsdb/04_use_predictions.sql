-- ========================================
-- Step 4: Use predictions
-- NOTE: Run each query SEPARATELY (one at a time)!
-- Run AFTER the model has finished training
-- ========================================

-- Query 1: Check that the model is ready (STATUS should be "complete")
DESCRIBE booking_forecast

-- Query 2: Show all models
-- SHOW MODELS

-- Query 3: Predict bookings for the next 14 days (MAIN QUERY!)
-- SELECT
--   booking_date,
--   CASE day_of_week
--     WHEN 0 THEN 'Sunday'
--     WHEN 1 THEN 'Monday'
--     WHEN 2 THEN 'Tuesday'
--     WHEN 3 THEN 'Wednesday'
--     WHEN 4 THEN 'Thursday'
--     WHEN 5 THEN 'Friday'
--     WHEN 6 THEN 'Saturday'
--   END as weekday,
--   booking_count as predicted_bookings
-- FROM booking_forecast
-- WHERE booking_date > CURRENT_DATE
-- ORDER BY booking_date
-- LIMIT 14

-- Query 4: Compare predictions with actual bookings (last week)
-- SELECT
--   'Actual' as type,
--   DATE_TRUNC('day', start_time) as date,
--   COUNT(*) as bookings
-- FROM awaio_postgres.bookings
-- WHERE start_time >= CURRENT_DATE - INTERVAL '7 days'
--   AND start_time < CURRENT_DATE
-- GROUP BY date
-- ORDER BY date
