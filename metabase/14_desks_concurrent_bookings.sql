-- Dashboard 14: Analysis of concurrent desk bookings per room
-- Shows desks in rooms with several desks and how often they are booked at the same time
-- Identifies under-use (many desks but few concurrent bookings)
-- Visualization: Table

WITH room_desks AS (
    -- Find rooms with several desks
    SELECT
        e.parent_id as room_id,
        parent.name as room_name,
        COUNT(*) as total_desks_in_room
    FROM entities e
    LEFT JOIN entities parent ON e.parent_id = parent.id
    WHERE e.group_tag = 'desk'
    GROUP BY e.parent_id, parent.name
    HAVING COUNT(*) > 1
),
desk_stats AS (
    -- Count total bookings per desk
    SELECT
        e.id as desk_id,
        e.name as desk_name,
        e.parent_id as room_id,
        COUNT(b.id) as total_bookings
    FROM entities e
    LEFT JOIN bookings b ON e.id = b.entity_id
    WHERE e.group_tag = 'desk'
      AND e.parent_id IN (SELECT room_id FROM room_desks)
    GROUP BY e.id, e.name, e.parent_id
),
concurrent_bookings AS (
    -- Count how many of the desk's bookings DO overlap with other bookings
    SELECT
        b1.entity_id as desk_id,
        COUNT(DISTINCT b1.id) as bookings_with_overlap
    FROM bookings b1
    JOIN entities e1 ON b1.entity_id = e1.id
    JOIN bookings b2 ON b1.id <> b2.id
    JOIN entities e2 ON b2.entity_id = e2.id
    WHERE e1.group_tag = 'desk'
      AND e2.group_tag = 'desk'
      AND e1.parent_id = e2.parent_id
      AND e1.parent_id IN (SELECT room_id FROM room_desks)
      AND b1.start_time < b2.end_time
      AND b1.end_time > b2.start_time
    GROUP BY b1.entity_id
)
SELECT
    ds.desk_name AS "Desk",
    rd.room_name AS "Area",
    rd.total_desks_in_room AS "Desks in room",
    ds.total_bookings AS "Total bookings",
    COALESCE(cb.bookings_with_overlap, 0) AS "Bookings with overlap",
    (ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0)) AS "Solo bookings",
    ROUND(
        (COALESCE(cb.bookings_with_overlap, 0)::NUMERIC / NULLIF(ds.total_bookings, 0) * 100),
        1
    ) AS "% with overlap",
    CASE
        WHEN ds.total_bookings = 0 THEN '⚪ Unbooked'
        WHEN COALESCE(cb.bookings_with_overlap, 0) = 0 THEN '🔴 Never concurrent'
        WHEN COALESCE(cb.bookings_with_overlap, 0)::NUMERIC / NULLIF(ds.total_bookings, 0) < 0.1 THEN '🟡 Rarely concurrent (<10%)'
        WHEN COALESCE(cb.bookings_with_overlap, 0)::NUMERIC / NULLIF(ds.total_bookings, 0) < 0.5 THEN '🟠 Sometimes concurrent (10-50%)'
        ELSE '🟢 Often concurrent (>50%)'
    END AS "Status"
FROM desk_stats ds
JOIN room_desks rd ON ds.room_id = rd.room_id
LEFT JOIN concurrent_bookings cb ON ds.desk_id = cb.desk_id
ORDER BY
    rd.room_name,
    "% with overlap" ASC,
    ds.total_bookings DESC;
