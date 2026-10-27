-- Dashboard 14: Analys av samtidiga skrivbordsbokningar per rum
-- Visar skrivbord i rum med flera skrivbord och hur ofta de bokas samtidigt
-- Identifierar underutnyttjande (många skrivbord men få samtidiga bokningar)
-- Visualisering: Table

WITH room_desks AS (
    -- Hitta rum med flera skrivbord
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
    -- Räkna totala bokningar per skrivbord
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
    -- Räkna hur många av skrivbordets bokningar som HAR överlapp med andra bokningar
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
    ds.desk_name AS "Skrivbord",
    rd.room_name AS "Område",
    rd.total_desks_in_room AS "Skrivbord i rummet",
    ds.total_bookings AS "Totala bokningar",
    COALESCE(cb.bookings_with_overlap, 0) AS "Bokningar med överlapp",
    (ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0)) AS "Ensamma bokningar",
    ROUND(
        (COALESCE(cb.bookings_with_overlap, 0)::NUMERIC / NULLIF(ds.total_bookings, 0) * 100),
        1
    ) AS "% med överlapp",
    CASE
        WHEN ds.total_bookings = 0 THEN '⚪ Obokad'
        WHEN COALESCE(cb.bookings_with_overlap, 0) = 0 THEN '🔴 Aldrig samtidigt'
        WHEN COALESCE(cb.bookings_with_overlap, 0)::NUMERIC / NULLIF(ds.total_bookings, 0) < 0.1 THEN '🟡 Sällan samtidigt (<10%)'
        WHEN COALESCE(cb.bookings_with_overlap, 0)::NUMERIC / NULLIF(ds.total_bookings, 0) < 0.5 THEN '🟠 Ibland samtidigt (10-50%)'
        ELSE '🟢 Ofta samtidigt (>50%)'
    END AS "Status"
FROM desk_stats ds
JOIN room_desks rd ON ds.room_id = rd.room_id
LEFT JOIN concurrent_bookings cb ON ds.desk_id = cb.desk_id
ORDER BY
    rd.room_name,
    "% med överlapp" ASC,
    ds.total_bookings DESC;
