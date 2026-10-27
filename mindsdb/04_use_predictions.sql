-- ========================================
-- Steg 4: Använd predictions
-- OBS: Kör varje query SEPARAT (en i taget)!
-- Kör EFTER att modellen tränats färdigt
-- ========================================

-- Query 1: Kontrollera att modellen är färdig (STATUS ska vara "complete")
DESCRIBE booking_forecast

-- Query 2: Visa alla modeller
-- SHOW MODELS

-- Query 3: Predicera bokningar för nästa 14 dagar (HUVUDQUERY!)
-- SELECT
--   booking_date,
--   CASE day_of_week
--     WHEN 0 THEN 'Söndag'
--     WHEN 1 THEN 'Måndag'
--     WHEN 2 THEN 'Tisdag'
--     WHEN 3 THEN 'Onsdag'
--     WHEN 4 THEN 'Torsdag'
--     WHEN 5 THEN 'Fredag'
--     WHEN 6 THEN 'Lördag'
--   END as weekday,
--   booking_count as predicted_bookings
-- FROM booking_forecast
-- WHERE booking_date > CURRENT_DATE
-- ORDER BY booking_date
-- LIMIT 14

-- Query 4: Jämför predictions med faktiska bokningar (senaste veckan)
-- SELECT
--   'Faktisk' as type,
--   DATE_TRUNC('day', start_time) as date,
--   COUNT(*) as bookings
-- FROM awaio_postgres.bookings
-- WHERE start_time >= CURRENT_DATE - INTERVAL '7 days'
--   AND start_time < CURRENT_DATE
-- GROUP BY date
-- ORDER BY date
