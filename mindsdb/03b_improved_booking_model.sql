-- Förbättrad bokningsprognos-modell
-- Denna version använder faktiska bokningsrader istället för aggregerad data

CREATE MODEL booking_forecast_v2
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('day', start_time) as booking_date,
     EXTRACT(DOW FROM start_time) as day_of_week,
     EXTRACT(HOUR FROM start_time) as hour_of_day,
     entity_id,
     owner_id
   FROM bookings
   WHERE start_time >= NOW() - INTERVAL '90 days'
     AND start_time < NOW())
PREDICT day_of_week

-- OBS: Detta tränar på faktiska bokningsrader och kan predicera
-- vilken veckodag som är mest trolig baserat på mönster
