-- Metabase Query: Team Room Bookings by Weekday (Last 4 Weeks vs Previous 4 Weeks)
--
-- Visar antal bokningar per teamrum och veckodag
-- Jämför senaste 4 veckor med 4 veckor innan
--
-- För Metabase: Använd som Native Query med Table visualization
-- OBS: Pivot Tables fungerar bara med Question Builder, inte Native SQL
-- Denna query ger en vanlig tabell som är lätt att läsa och filtrera

WITH date_ranges AS (
  -- Definiera tidsperioderna
  SELECT
    CURRENT_DATE - INTERVAL '28 days' AS current_period_start,
    CURRENT_DATE AS current_period_end,
    CURRENT_DATE - INTERVAL '56 days' AS previous_period_start,
    CURRENT_DATE - INTERVAL '28 days' AS previous_period_end
),

room_bookings AS (
  -- Hämta alla bokningar för teamrum
  SELECT
    e.name AS room_name,
    e.id AS entity_id,
    b.id AS booking_id,
    b.start_time,
    b.end_time,
    -- Extrahera veckodag (1=Måndag, 7=Söndag)
    EXTRACT(ISODOW FROM b.start_time) AS weekday_num,
    CASE EXTRACT(ISODOW FROM b.start_time)
      WHEN 1 THEN 'Måndag'
      WHEN 2 THEN 'Tisdag'
      WHEN 3 THEN 'Onsdag'
      WHEN 4 THEN 'Torsdag'
      WHEN 5 THEN 'Fredag'
      WHEN 6 THEN 'Lördag'
      WHEN 7 THEN 'Söndag'
    END AS weekday_name,
    -- Avgör vilken period bokningen tillhör
    CASE
      WHEN b.start_time >= (SELECT current_period_start FROM date_ranges)
           AND b.start_time < (SELECT current_period_end FROM date_ranges)
      THEN 'current'
      WHEN b.start_time >= (SELECT previous_period_start FROM date_ranges)
           AND b.start_time < (SELECT previous_period_end FROM date_ranges)
      THEN 'previous'
      ELSE NULL
    END AS period
  FROM entities e
  INNER JOIN bookings b ON e.id = b.entity_id
  WHERE
    -- Filtrera endast teamrum (rooms, inte desks eller lockers)
    e.group_tag = 'room'
    AND b.status = 'reserved'
    -- Filtrera på senaste 8 veckor
    AND b.start_time >= (SELECT previous_period_start FROM date_ranges)
    AND b.start_time < (SELECT current_period_end FROM date_ranges)
    -- Exkludera helger (valfritt)
    AND EXTRACT(ISODOW FROM b.start_time) BETWEEN 1 AND 5
)

-- Aggregera data per rum och veckodag
SELECT
  room_name AS "Rum",
  weekday_name AS "Veckodag",
  COUNT(CASE WHEN period = 'current' THEN 1 END) AS "Senaste 4 veckor",
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "4 veckor innan",
  COUNT(CASE WHEN period = 'current' THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Förändring",
  CASE
    WHEN COUNT(CASE WHEN period = 'previous' THEN 1 END) > 0 THEN
      ROUND(
        (COUNT(CASE WHEN period = 'current' THEN 1 END)::DECIMAL -
         COUNT(CASE WHEN period = 'previous' THEN 1 END)::DECIMAL) /
        COUNT(CASE WHEN period = 'previous' THEN 1 END)::DECIMAL * 100,
        1
      )
    ELSE NULL
  END AS "Förändring %"
FROM room_bookings
WHERE period IS NOT NULL
GROUP BY room_name, weekday_name, weekday_num
ORDER BY room_name, weekday_num;

-- ========================================
-- ALTERNATIV QUERY: PIVOTERAD TABELL
-- ========================================
-- Veckodagar som kolumner - lättare att läsa per rum
-- Ta bort kommentarerna för att använda denna query istället

/*
WITH date_ranges AS (
  SELECT
    CURRENT_DATE - INTERVAL '28 days' AS current_period_start,
    CURRENT_DATE AS current_period_end,
    CURRENT_DATE - INTERVAL '56 days' AS previous_period_start,
    CURRENT_DATE - INTERVAL '28 days' AS previous_period_end
),
room_bookings AS (
  SELECT
    e.name AS room_name,
    EXTRACT(ISODOW FROM b.start_time) AS weekday_num,
    CASE
      WHEN b.start_time >= (SELECT current_period_start FROM date_ranges)
           AND b.start_time < (SELECT current_period_end FROM date_ranges)
      THEN 'current'
      WHEN b.start_time >= (SELECT previous_period_start FROM date_ranges)
           AND b.start_time < (SELECT previous_period_end FROM date_ranges)
      THEN 'previous'
      ELSE NULL
    END AS period
  FROM entities e
  INNER JOIN bookings b ON e.id = b.entity_id
  WHERE
    e.group_tag = 'room'
    AND b.status = 'reserved'
    AND b.start_time >= (SELECT previous_period_start FROM date_ranges)
    AND b.start_time < (SELECT current_period_end FROM date_ranges)
    AND EXTRACT(ISODOW FROM b.start_time) BETWEEN 1 AND 5
)
SELECT
  room_name AS "Rum",
  -- Måndag
  COUNT(CASE WHEN period = 'current' AND weekday_num = 1 THEN 1 END) AS "Mån (nu)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 1 THEN 1 END) AS "Mån (4v innan)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 1 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 1 THEN 1 END) AS "Mån Δ",
  -- Tisdag
  COUNT(CASE WHEN period = 'current' AND weekday_num = 2 THEN 1 END) AS "Tis (nu)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 2 THEN 1 END) AS "Tis (4v innan)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 2 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 2 THEN 1 END) AS "Tis Δ",
  -- Onsdag
  COUNT(CASE WHEN period = 'current' AND weekday_num = 3 THEN 1 END) AS "Ons (nu)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 3 THEN 1 END) AS "Ons (4v innan)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 3 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 3 THEN 1 END) AS "Ons Δ",
  -- Torsdag
  COUNT(CASE WHEN period = 'current' AND weekday_num = 4 THEN 1 END) AS "Tor (nu)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 4 THEN 1 END) AS "Tor (4v innan)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 4 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 4 THEN 1 END) AS "Tor Δ",
  -- Fredag
  COUNT(CASE WHEN period = 'current' AND weekday_num = 5 THEN 1 END) AS "Fre (nu)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 5 THEN 1 END) AS "Fre (4v innan)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 5 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 5 THEN 1 END) AS "Fre Δ",
  -- Totaler
  COUNT(CASE WHEN period = 'current' THEN 1 END) AS "Totalt (nu)",
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Totalt (4v innan)",
  COUNT(CASE WHEN period = 'current' THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Total Δ"
FROM room_bookings
WHERE period IS NOT NULL
GROUP BY room_name
ORDER BY room_name;
*/

-- ========================================
-- ANVISNINGAR FÖR METABASE
-- ========================================
--
-- VARIANT 1: TABELL MED RADER PER RUM OCH VECKODAG (REKOMMENDERAS)
-- 1. Skapa ny fråga i Metabase
-- 2. Välj "Native Query" (SQL)
-- 3. Klistra in huvudqueryn ovan
-- 4. Spara som "Teamrum - Bokningar per veckodag"
-- 5. Visualization → Table
-- 6. Sortera på "Förändring %" för att se största skillnaderna
-- 7. Använd conditional formatting:
--    - "Förändring" > 0 → Grön
--    - "Förändring" < 0 → Röd
--
-- VARIANT 2: PIVOTERAD TABELL MED VECKODAGAR SOM KOLUMNER
-- 1. Använd alternativ query nedan (ta bort kommentarerna)
-- 2. Varje veckodag blir en egen kolumn
-- 3. Lättare att jämföra samma rum över veckodagar
-- 4. Bättre för utskrift och övergripande analys
--
-- TIPS:
-- - Lägg till filter för specifika rum
-- - Skapa dashboard med båda varianter
-- - Exportera till CSV för vidare analys i Excel
