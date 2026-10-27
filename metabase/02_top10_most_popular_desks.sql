-- Dashboard 2: Top 10 most popular desks
-- Shows the 10 desks with the most bookings in total, with average duration
-- Visualization: Horizontal bar chart or Table

SELECT
    e.name AS "Desk",
    e.id AS entity_id,
    COUNT(b.id) AS "Bookings",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Avg hours/booking",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours",
    e.parent_id,
    parent.name AS "Area"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'desk'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY "Bookings" DESC
LIMIT 10;
