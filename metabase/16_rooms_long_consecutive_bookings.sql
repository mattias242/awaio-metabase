-- Dashboard 16: Rooms with long bookings (>4h) on several days in a row
-- Identifies rooms often booked for a long time over several consecutive days
-- This may indicate rooms used for long meetings, workshops or permanent allocation
-- Visualization: Table

WITH long_bookings AS (
    -- All room bookings longer than 4 hours
    SELECT
        b.id AS booking_id,
        b.entity_id,
        e.name AS room_name,
        parent.name AS area,
        b.owner_id,
        DATE(b.start_time) AS booking_date,
        b.start_time,
        b.end_time,
        EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 AS hours,
        u.name AS user_name
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN entities parent ON e.parent_id = parent.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE e.group_tag = 'room'
      AND EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 > 4
      AND b.status = 'reserved'
),
consecutive_bookings AS (
    -- Find consecutive days for the same room and user
    SELECT
        lb1.entity_id,
        lb1.room_name,
        lb1.area,
        lb1.owner_id,
        lb1.user_name,
        lb1.booking_date AS start_date,
        COUNT(DISTINCT lb2.booking_date) AS consecutive_days,
        MIN(lb2.start_time) AS first_booking_start,
        MAX(lb2.end_time) AS last_booking_end,
        ROUND(AVG(lb2.hours)::numeric, 1) AS avg_hours_per_day,
        ROUND(SUM(lb2.hours)::numeric, 1) AS total_hours
    FROM long_bookings lb1
    JOIN long_bookings lb2
        ON lb1.entity_id = lb2.entity_id
        AND lb1.owner_id = lb2.owner_id
        AND lb2.booking_date BETWEEN lb1.booking_date AND lb1.booking_date + INTERVAL '6 days'
    GROUP BY lb1.entity_id, lb1.room_name, lb1.area, lb1.owner_id, lb1.user_name, lb1.booking_date
    HAVING COUNT(DISTINCT lb2.booking_date) >= 2  -- At least 2 days in a row
),
room_stats AS (
    -- Aggregate statistics per room
    SELECT
        entity_id,
        room_name,
        area,
        COUNT(DISTINCT owner_id) AS user_count,
        COUNT(*) AS series_count,
        ROUND(AVG(consecutive_days)::numeric, 1) AS avg_days_in_row,
        MAX(consecutive_days) AS max_days_in_row,
        ROUND(AVG(avg_hours_per_day)::numeric, 1) AS avg_hours_per_day,
        ROUND(SUM(total_hours)::numeric, 1) AS total_hours_all_series
    FROM consecutive_bookings
    GROUP BY entity_id, room_name, area
)
SELECT
    room_name AS "Room",
    area AS "Area",
    series_count AS "Booking series",
    user_count AS "Users",
    avg_days_in_row AS "Avg days in a row",
    max_days_in_row AS "Max days in a row",
    avg_hours_per_day AS "Avg hours/day",
    total_hours_all_series AS "Total hours"
FROM room_stats
ORDER BY series_count DESC, max_days_in_row DESC, avg_hours_per_day DESC
LIMIT 20;
