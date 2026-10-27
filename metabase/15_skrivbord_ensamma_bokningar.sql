-- Dashboard 15: Skrivbord som oftast bokas ensamma
-- Visar skrivbord i rum med flera skrivbord som har flest "ensamma" bokningar
-- (bokningar utan överlapp med andra skrivbord i samma rum)
-- Identifierar potentiellt underutnyttjande av rumsutrymme
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
    -- Räkna hur många av skrivbordets bokningar som HAR överlapp
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
    (ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0)) AS "Ensamma bokningar",
    ROUND(
        ((ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0))::NUMERIC /
         NULLIF(ds.total_bookings, 0) * 100),
        1
    ) AS "% ensamma bokningar",
    CASE
        WHEN ds.total_bookings = 0 THEN '⚪ Obokad'
        WHEN (ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0)) = 0 THEN '🟢 Aldrig ensam'
        WHEN ((ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0))::NUMERIC /
              NULLIF(ds.total_bookings, 0)) < 0.1 THEN '🟢 Nästan aldrig ensam (<10%)'
        WHEN ((ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0))::NUMERIC /
              NULLIF(ds.total_bookings, 0)) < 0.3 THEN '🟡 Sällan ensam (10-30%)'
        WHEN ((ds.total_bookings - COALESCE(cb.bookings_with_overlap, 0))::NUMERIC /
              NULLIF(ds.total_bookings, 0)) < 0.5 THEN '🟠 Ibland ensam (30-50%)'
        ELSE '🔴 Ofta ensam (>50%)'
    END AS "Status"
FROM desk_stats ds
JOIN room_desks rd ON ds.room_id = rd.room_id
LEFT JOIN concurrent_bookings cb ON ds.desk_id = cb.desk_id
WHERE ds.total_bookings > 0  -- Endast bokade skrivbord
ORDER BY
    "% ensamma bokningar" DESC,
    ds.total_bookings DESC;
