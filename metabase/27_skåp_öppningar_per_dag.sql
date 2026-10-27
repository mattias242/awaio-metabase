-- Dashboard 27: Skåpsöppningar per dag inom datumintervall
-- Visar antal gånger skåp öppnas (bokningar) varje dag, antal användare och skåp
-- Fokus på ÖPPNINGAR (antal bokningar) snarare än antal unika skåp
-- Visualisering: Line Chart (trend) eller Column Chart (per dag)
--
-- OBS: Använd Metabase's datum-filter för att välja period
-- Alternativt: Ändra WHERE-clause för att sätta specifika datum

SELECT
    DATE(b.start_time) AS "Datum",
    COUNT(b.id) AS "Antal öppningar",  -- Antal bokningar = antal gånger skåp öppnas
    COUNT(DISTINCT b.entity_id) AS "Antal olika skåp",  -- Hur många skåp som användes
    COUNT(DISTINCT b.owner_id) AS "Antal användare",  -- Hur många personer
    -- Genomsnittlig bokningstid per öppning
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Snitt timmar/öppning",
    -- Total bokad tid per dag
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total timmar",
    -- Genomsnittliga öppningar per skåp
    ROUND(COUNT(b.id)::numeric / NULLIF(COUNT(DISTINCT b.entity_id), 0), 1) AS "Öppningar/skåp"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  -- Ändra dessa datum eller använd Metabase filter
  AND b.start_time >= '2025-01-01'::date
  AND b.start_time < '2025-12-31'::date + INTERVAL '1 day'
GROUP BY DATE(b.start_time)
ORDER BY DATE(b.start_time) ASC;
