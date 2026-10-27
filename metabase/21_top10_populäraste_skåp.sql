-- Dashboard 21: Top 10 populäraste skåp
-- Visar de 10 skåp som har flest bokningar totalt med snitttid och antal användare
-- "Antal användare" visar hur många olika personer som har öppnat/använt skåpet
-- Visualisering: Horizontal bar chart eller Table

SELECT
    e.name AS "Skåp",
    e.id AS entity_id,
    COUNT(b.id) AS "Antal bokningar",
    COUNT(DISTINCT b.owner_id) AS "Antal användare",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Snitt timmar/bokning",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Totalt antal timmar",
    e.parent_id,
    parent.name AS "Område"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY "Antal bokningar" DESC
LIMIT 10;
