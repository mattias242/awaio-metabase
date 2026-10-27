-- Dashboard 12: Top 10 least popular desks
-- Shows the 10 desks with the fewest bookings (under-used resources)
-- Visualization: Horizontal bar chart or Table

SELECT
    e.name AS "Desk",
    e.id AS entity_id,
    COUNT(b.id) AS "Bookings",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Avg hours/booking",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 60)::numeric, 0) AS "Avg minutes/booking",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours",
    e.parent_id,
    parent.name AS "Area"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'desk'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY "Bookings" ASC
LIMIT 10;
