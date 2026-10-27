-- Dashboard 22: Top 10 least popular lockers
-- Shows the 10 lockers with the fewest bookings (under-used resources)
-- "Users" shows how many different people have opened/used the locker
-- Visualization: Horizontal bar chart or Table

SELECT
    e.name AS "Locker",
    e.id AS entity_id,
    COUNT(b.id) AS "Bookings",
    COUNT(DISTINCT b.owner_id) AS "Users",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Avg hours/booking",
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 60)::numeric, 0) AS "Avg minutes/booking",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours",
    e.parent_id,
    parent.name AS "Area"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY "Bookings" ASC
LIMIT 10;
