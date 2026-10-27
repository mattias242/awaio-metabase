-- Dashboard 26: Detailed booking matrix for lockers per day
-- Shows which specific lockers are booked on which days (pivot/matrix view)
-- Useful for seeing exactly which lockers are used when
-- Visualization: Table (pivot table possible in Metabase)
--
-- METABASE PARAMETERS (optional):
--   Name: "days" → Type: Number → Default: 30

SELECT
    e.name AS "Locker",
    parent.name AS "Area",
    DATE(b.start_time) AS "Date",
    COUNT(b.id) AS "Bookings",
    COUNT(DISTINCT b.owner_id) AS "Users",
    STRING_AGG(DISTINCT u.name, ', ' ORDER BY u.name) AS "Users list",
    MIN(b.start_time)::time AS "First booking",
    MAX(b.end_time)::time AS "Last booking",
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN users u ON b.owner_id = u.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  -- Last 30 days (or use a Metabase parameter)
  AND b.start_time >= NOW() - INTERVAL '30 days'
  -- [[AND b.start_time >= NOW() - INTERVAL '{{days}} days']]
GROUP BY e.id, e.name, parent.name, DATE(b.start_time)
ORDER BY DATE(b.start_time) DESC, parent.name, e.name;
