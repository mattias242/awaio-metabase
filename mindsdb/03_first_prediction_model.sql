-- Steg 3: Skapa din första prediktionsmodell
-- Denna modell predicerar antal bokningar per dag
-- OBS: För open source MindsDB, använd lightwood engine (default)

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

-- OBS: Detta kan ta 2-5 minuter första gången!
-- Du kan se status med: DESCRIBE booking_forecast;
