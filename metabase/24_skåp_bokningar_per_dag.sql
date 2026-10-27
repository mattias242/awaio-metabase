-- Dashboard 24: Bokade skåp per dag inom datumintervall
-- Visar antal unika skåp som är bokade varje dag, totalt antal bokningar och användare
-- Användbart för att se utnyttjandegrad över tid och identifiera toppar/dalar
-- Visualisering: Line Chart (trend) eller Column Chart (per dag)
--
-- OBS: Använd Metabase's datum-filter för att välja period
-- Alternativt: Ändra WHERE-clause för att sätta specifika datum

SELECT
    DATE(b.start_time) AS "Datum",
    COUNT(DISTINCT b.entity_id) AS "Antal bokade skåp",
    COUNT(b.id) AS "Antal bokningar",
    COUNT(DISTINCT b.owner_id) AS "Antal användare",
    -- Genomsnittlig bokningstid per dag
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Snitt timmar/bokning",
    -- Total bokad tid per dag
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total timmar"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  -- Ändra dessa datum eller använd Metabase filter
  AND b.start_time >= '2025-01-01'::date
  AND b.start_time < '2025-12-31'::date + INTERVAL '1 day'
GROUP BY DATE(b.start_time)
ORDER BY DATE(b.start_time) ASC;
