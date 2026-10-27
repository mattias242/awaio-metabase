-- ========================================
-- Step 2: Test the connection
-- NOTE: Run each query SEPARATELY (one at a time)!
-- ========================================

-- Query 1: Show all databases (you should see awaio_postgres here)
SHOW DATABASES

-- Query 2: Test reading from the bookings table
-- SELECT * FROM awaio_postgres.bookings LIMIT 10

-- Query 3: Show all tables in awaio_postgres
-- SHOW TABLES FROM awaio_postgres

-- Query 4: See statistics on your bookings
-- SELECT
--   COUNT(*) as total_bookings,
--   COUNT(DISTINCT owner_id) as unique_users,
--   COUNT(DISTINCT entity_id) as unique_entities,
--   MIN(start_time) as earliest_booking,
--   MAX(start_time) as latest_booking
-- FROM awaio_postgres.bookings
