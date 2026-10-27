-- Dashboard 10: Top 10 minst populära rum
-- Visar de 10 rum som har minst bokningar (underutnyttjade resurser)
-- Visualisering: Horizontal bar chart eller Table

SELECT
    e.name AS "Rum",
    e.id AS entity_id,
    COUNT(b.id) AS "Antal bokningar",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Snitt timmar/bokning",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 60)::numeric, 0) AS "Snitt minuter/bokning",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Totalt antal timmar",
    e.parent_id,
    parent.name AS "Område"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'room'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY "Antal bokningar" ASC
LIMIT 10;
