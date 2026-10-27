-- Dashboard 4: Top 10 most popular rooms with average booking duration
-- Shows the 10 rooms with the most bookings and the average time per booking
-- Visualization: Table

SELECT
    e.name AS room,
    e.id AS entity_id,
    COUNT(b.id) AS bookings,
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS avg_hours_per_booking,
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 60)::numeric, 0) AS avg_minutes_per_booking,
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS total_hours,
    e.parent_id,
    parent.name AS area
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'room'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY bookings DESC
LIMIT 10;
