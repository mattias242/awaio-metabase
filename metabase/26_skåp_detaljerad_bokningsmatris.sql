-- Dashboard 26: Detaljerad bokningsmatris för skåp per dag
-- Visar vilka specifika skåp som är bokade vilka dagar (pivot/matrix view)
-- Användbart för att se exakt vilka skåp som används när
-- Visualisering: Table (pivot table möjlig i Metabase)
--
-- METABASE PARAMETRAR (valfritt):
--   Namn: "antal_dagar" → Type: Number → Default: 30

SELECT
    e.name AS "Skåp",
    parent.name AS "Område",
    DATE(b.start_time) AS "Datum",
    COUNT(b.id) AS "Antal bokningar",
    COUNT(DISTINCT b.owner_id) AS "Antal användare",
    STRING_AGG(DISTINCT u.name, ', ' ORDER BY u.name) AS "Användare",
    MIN(b.start_time)::time AS "Första bokning",
    MAX(b.end_time)::time AS "Sista bokning",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total timmar"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN users u ON b.owner_id = u.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  -- Senaste 30 dagarna (eller använd Metabase parameter)
  AND b.start_time >= NOW() - INTERVAL '30 days'
  -- [[AND b.start_time >= NOW() - INTERVAL '{{antal_dagar}} days']]
GROUP BY e.id, e.name, parent.name, DATE(b.start_time)
ORDER BY DATE(b.start_time) DESC, parent.name, e.name;
