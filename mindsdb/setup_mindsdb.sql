-- MindsDB Setup Script för Awaio
-- Kör denna fil i MindsDB Web UI (http://localhost:47334) eller via MySQL client
-- Detta script skapar databasanslutning och grundläggande ML-modeller

-- ===========================================
-- STEG 1: Anslut till PostgreSQL
-- ===========================================

CREATE DATABASE awaio_postgres
WITH ENGINE = 'postgres',
PARAMETERS = {
  "host": "postgres",
  "port": 5432,
  "database": "awaio_db",
  "user": "awaio_user",
  "password": "change_me"
};

-- Verifiera anslutningen
SHOW DATABASES;

-- Testa att läsa data
SELECT * FROM awaio_postgres.bookings LIMIT 5;

-- ===========================================
-- STEG 2: Skapa Bokningsprognos-modell
-- ===========================================

CREATE MODEL booking_forecaster
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('day', start_time)::date as booking_date,
     EXTRACT(DOW FROM start_time)::int as day_of_week,
     EXTRACT(WEEK FROM start_time)::int as week_number,
     COUNT(*)::int as booking_count
   FROM bookings
   WHERE start_time >= NOW() - INTERVAL '90 days'
     AND start_time < NOW()
   GROUP BY booking_date, day_of_week, week_number
   ORDER BY booking_date)
PREDICT booking_count
ORDER BY booking_date
USING
  engine = 'statsforecast',
  horizon = 14;

-- ===========================================
-- STEG 3: Skapa Kapacitetsutnyttjande-modell
-- ===========================================

CREATE MODEL hourly_capacity_predictor
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('hour', b.start_time)::timestamp as time_slot,
     EXTRACT(DOW FROM b.start_time)::int as day_of_week,
     EXTRACT(HOUR FROM b.start_time)::int as hour_of_day,
     COUNT(DISTINCT b.entity_id)::int as desks_in_use
   FROM bookings b
   JOIN entities e ON b.entity_id = e.id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '60 days'
   GROUP BY time_slot, day_of_week, hour_of_day
   ORDER BY time_slot)
PREDICT desks_in_use
ORDER BY time_slot
USING
  engine = 'lightwood';

-- ===========================================
-- STEG 4: Skapa Skrivbordspopularitets-modell
-- ===========================================

CREATE MODEL desk_popularity_predictor
FROM awaio_postgres
  (SELECT
     e.id as desk_id,
     e.name as desk_name,
     DATE_TRUNC('week', b.start_time)::date as week_start,
     COUNT(b.id)::int as weekly_bookings,
     COUNT(DISTINCT b.owner_id)::int as unique_users,
     ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) as avg_hours
   FROM entities e
   JOIN bookings b ON e.id = b.entity_id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '90 days'
   GROUP BY e.id, e.name, week_start
   ORDER BY week_start, desk_id)
PREDICT weekly_bookings
ORDER BY desk_id, week_start
USING
  engine = 'lightwood';

-- ===========================================
-- STEG 5: Verifiera att modellerna skapats
-- ===========================================

SHOW MODELS;

-- ===========================================
-- EXEMPEL: Testa predictions
-- ===========================================

-- Prediction 1: Bokningar nästa 14 dagar
SELECT
  booking_date,
  CASE day_of_week
    WHEN 0 THEN 'Söndag'
    WHEN 1 THEN 'Måndag'
    WHEN 2 THEN 'Tisdag'
    WHEN 3 THEN 'Onsdag'
    WHEN 4 THEN 'Torsdag'
    WHEN 5 THEN 'Fredag'
    WHEN 6 THEN 'Lördag'
  END as weekday,
  booking_count as predicted_bookings
FROM booking_forecaster
WHERE booking_date > CURRENT_DATE
ORDER BY booking_date
LIMIT 14;

-- Prediction 2: Kapacitet imorgon per timme
SELECT
  time_slot,
  hour_of_day,
  desks_in_use as predicted_desks_in_use,
  ROUND((desks_in_use::numeric / 57 * 100), 1) as utilization_percentage
FROM hourly_capacity_predictor
WHERE time_slot::date = CURRENT_DATE + INTERVAL '1 day'
ORDER BY hour_of_day;

-- Prediction 3: Mest populära skrivbord nästa vecka
SELECT
  desk_name,
  weekly_bookings as predicted_bookings,
  unique_users as predicted_unique_users
FROM desk_popularity_predictor
WHERE week_start = DATE_TRUNC('week', CURRENT_DATE + INTERVAL '7 days')
ORDER BY predicted_bookings DESC
LIMIT 10;
