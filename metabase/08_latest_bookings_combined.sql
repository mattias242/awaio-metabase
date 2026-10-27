-- Dashboard 8: The 5 latest bookings (desks + rooms combined)
-- Shows the very latest bookings regardless of type
-- Visualization: Table

SELECT
    b.start_time AS "Start time",
    CASE
        WHEN e.group_tag = 'desk' THEN '🖥️ Desk'
        WHEN e.group_tag = 'room' THEN '🏢 Room'
        WHEN e.group_tag = 'storage' THEN '🔒 Locker'
        ELSE e.group_tag
    END AS "Type",
    e.name AS "Resource",
    parent.name AS "Area",
    u.email AS "Booked by",
    ROUND(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600, 1) AS "Hours",
    CASE
        WHEN b.cancelled THEN '❌ Cancelled'
        WHEN b.end_time < NOW() THEN '✅ Ended'
        WHEN b.start_time > NOW() THEN '🕐 Upcoming'
        ELSE '▶️ Ongoing'
    END AS "Status",
    b.created_at AS "Booked at"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN booking_organizers bo ON b.id = bo.booking_id
LEFT JOIN users u ON bo.user_id = u.id
WHERE e.group_tag IN ('desk', 'room', 'storage')
ORDER BY b.created_at DESC
LIMIT 5;
