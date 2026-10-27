-- Predict bookings for the latest bookings
-- IMPORTANT: MindsDB requires JOIN syntax for predictions!
-- 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday

SELECT
  m.booking_date,
  m.day_of_week,
  m.booking_count as predicted_bookings
FROM booking_forecast AS m
JOIN awaio_postgres.bookings AS t
LIMIT 14
