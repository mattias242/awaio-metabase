-- See statistics on your bookings
SELECT
  COUNT(*) as total_bookings,
  COUNT(DISTINCT owner_id) as unique_users,
  COUNT(DISTINCT entity_id) as unique_entities,
  MIN(start_time) as earliest_booking,
  MAX(start_time) as latest_booking
FROM awaio_postgres.bookings
