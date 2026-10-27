-- Dashboard 4: Top 10 populäraste rum med genomsnittlig bokningstid
-- Visar de 10 rum som har flest bokningar med snitttid per bokning
-- Visualisering: Table

SELECT
    e.name AS rum,
    e.id AS entity_id,
    COUNT(b.id) AS antal_bokningar,
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS snitt_timmar_per_bokning,
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 60)::numeric, 0) AS snitt_minuter_per_bokning,
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS totalt_antal_timmar,
    e.parent_id,
    parent.name AS område
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'room'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY antal_bokningar DESC
LIMIT 10;
