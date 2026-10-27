-- Dashboard 7: The 5 most recently booked Teams rooms
-- Shows the latest room bookings in real time
-- Visualization: Table

SELECT
    b.start_time AS "Start time",
    e.name AS "Room",
    parent.name AS "Area",
    u.email AS "Booked by",
    EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 AS "Hours",
    CASE
        WHEN b.cancelled THEN 'Cancelled'
        WHEN b.end_time < NOW() THEN 'Ended'
        WHEN b.start_time > NOW() THEN 'Upcoming'
        ELSE 'Ongoing'
    END AS "Status",
    b.created_at AS "Booked at"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN booking_organizers bo ON b.id = bo.booking_id
LEFT JOIN users u ON bo.user_id = u.id
WHERE e.group_tag = 'room'
ORDER BY b.created_at DESC
LIMIT 5;
