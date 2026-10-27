-- Dashboard 3: Top 10 desks with the most unique users
-- Shows the 10 desks that the most different people have tried
-- Visualization: Horizontal bar chart or Table

SELECT
    e.name AS desk,
    e.id AS entity_id,
    COUNT(DISTINCT bo.user_id) AS unique_users,
    COUNT(b.id) AS total_bookings,
    e.parent_id,
    parent.name AS area
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
JOIN booking_organizers bo ON b.id = bo.booking_id
WHERE e.group_tag = 'desk'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY unique_users DESC
LIMIT 10;
