-- Dashboard 25: Bokade skåp per dag - PARAMETRISERAD VERSION
-- Visar antal unika skåp som är bokade varje dag, totalt antal bokningar och användare
-- Användbar för att se utnyttjandegrad över tid och identifiera toppar/dalar
-- Visualisering: Line Chart (trend) eller Column Chart (per dag)
--
-- METABASE PARAMETRAR:
-- När du skapar denna query i Metabase, lägg till två "Field Filter" parametrar:
--   1. Namn: "startdatum" → Type: Date → Default: 30 days ago
--   2. Namn: "slutdatum" → Type: Date → Default: today
--
-- Metabase kommer automatiskt ersätta {{startdatum}} och {{slutdatum}} med valda värden

SELECT
    DATE(b.start_time) AS "Datum",
    COUNT(DISTINCT b.entity_id) AS "Antal bokade skåp",
    COUNT(b.id) AS "Antal bokningar",
    COUNT(DISTINCT b.owner_id) AS "Antal användare",
    -- Genomsnittlig bokningstid per dag
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Snitt timmar/bokning",
    -- Total bokad tid per dag
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total timmar",
    -- Utnyttjandegrad (om du vet totalt antal skåp)
    ROUND((COUNT(DISTINCT b.entity_id)::numeric /
           (SELECT COUNT(*) FROM entities WHERE group_tag = 'storage')::numeric * 100), 1) AS "% utnyttjade skåp"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  [[AND b.start_time >= {{startdatum}}]]
  [[AND b.start_time < {{slutdatum}} + INTERVAL '1 day']]
GROUP BY DATE(b.start_time)
ORDER BY DATE(b.start_time) ASC;
