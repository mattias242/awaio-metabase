-- Dashboard 5: Top 10 most active users with their 5 most used desks
-- Shows the 10 users with the most bookings and their 5 most booked desks
-- Visualization: Table (pivot format)

WITH user_desk_bookings AS (
    -- Count bookings per user and desk
    SELECT
        u.email AS user_email,
        COALESCE(u.name, SPLIT_PART(u.email, '@', 1)) AS user_name,
        e.name AS desk,
        COUNT(b.id) AS bookings,
        ROW_NUMBER() OVER (PARTITION BY u.email ORDER BY COUNT(b.id) DESC) AS rank
    FROM booking_organizers bo
    JOIN users u ON bo.user_id = u.id
    JOIN bookings b ON bo.booking_id = b.id
    JOIN entities e ON b.entity_id = e.id
    WHERE e.group_tag = 'desk'
    GROUP BY u.email, u.name, e.name
),
top_users AS (
    -- Find the 10 most active users
    SELECT
        u.email AS user_email,
        COALESCE(u.name, SPLIT_PART(u.email, '@', 1)) AS user_name,
        COUNT(DISTINCT b.id) AS total_bookings
    FROM booking_organizers bo
    JOIN users u ON bo.user_id = u.id
    JOIN bookings b ON bo.booking_id = b.id
    JOIN entities e ON b.entity_id = e.id
    WHERE e.group_tag = 'desk'
    GROUP BY u.email, u.name
    ORDER BY total_bookings DESC
    LIMIT 10
)
SELECT
    tu.user_name,
    tu.total_bookings,
    MAX(CASE WHEN udb.rank = 1 THEN udb.desk || ' (' || udb.bookings || ')' END) AS "Desk 1",
    MAX(CASE WHEN udb.rank = 2 THEN udb.desk || ' (' || udb.bookings || ')' END) AS "Desk 2",
    MAX(CASE WHEN udb.rank = 3 THEN udb.desk || ' (' || udb.bookings || ')' END) AS "Desk 3",
    MAX(CASE WHEN udb.rank = 4 THEN udb.desk || ' (' || udb.bookings || ')' END) AS "Desk 4",
    MAX(CASE WHEN udb.rank = 5 THEN udb.desk || ' (' || udb.bookings || ')' END) AS "Desk 5"
FROM top_users tu
LEFT JOIN user_desk_bookings udb ON tu.user_email = udb.user_email AND udb.rank <= 5
GROUP BY tu.user_name, tu.total_bookings
ORDER BY tu.total_bookings DESC;
