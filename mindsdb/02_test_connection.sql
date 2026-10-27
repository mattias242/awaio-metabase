-- ========================================
-- Steg 2: Testa anslutningen
-- OBS: Kör varje query SEPARAT (en i taget)!
-- ========================================

-- Query 1: Visa alla databaser (du ska se awaio_postgres här)
SHOW DATABASES

-- Query 2: Testa att läsa från bookings-tabellen
-- SELECT * FROM awaio_postgres.bookings LIMIT 10

-- Query 3: Visa alla tabeller i awaio_postgres
-- SHOW TABLES FROM awaio_postgres

-- Query 4: Se statistik över dina bokningar
-- SELECT
--   COUNT(*) as total_bookings,
--   COUNT(DISTINCT owner_id) as unique_users,
--   COUNT(DISTINCT entity_id) as unique_entities,
--   MIN(start_time) as earliest_booking,
--   MAX(start_time) as latest_booking
-- FROM awaio_postgres.bookings
