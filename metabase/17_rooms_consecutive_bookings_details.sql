-- Dashboard 17: Detailed view of consecutive bookings per room
-- Shows specific booking series with dates, users and times
-- Helps identify patterns in how rooms are used over several days
-- Visualization: Table (can be filtered on room_name)

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
consecutive_series AS (
    -- Identify series of consecutive bookings
    SELECT
        lb1.entity_id,
        lb1.room_name,
        lb1.area,
        lb1.owner_id,
        lb1.user_name,
        MIN(lb1.booking_date) AS series_start_date,
        MAX(lb2.booking_date) AS series_end_date,
        COUNT(DISTINCT lb2.booking_date) AS days_in_row,
        MIN(lb2.start_time) AS first_booking,
        MAX(lb2.end_time) AS last_booking,
        ROUND(AVG(lb2.hours)::numeric, 1) AS avg_hours_per_day,
        ROUND(SUM(lb2.hours)::numeric, 1) AS total_hours,
        STRING_AGG(
            TO_CHAR(lb2.booking_date, 'YYYY-MM-DD') || ' (' || ROUND(lb2.hours::numeric, 1) || 'h)',
            ', '
            ORDER BY lb2.booking_date
        ) AS date_list
    FROM long_bookings lb1
    JOIN long_bookings lb2
        ON lb1.entity_id = lb2.entity_id
        AND lb1.owner_id = lb2.owner_id
        AND lb2.booking_date BETWEEN lb1.booking_date AND lb1.booking_date + INTERVAL '6 days'
    GROUP BY lb1.entity_id, lb1.room_name, lb1.area, lb1.owner_id, lb1.user_name, lb1.booking_date
    HAVING COUNT(DISTINCT lb2.booking_date) >= 2
)
SELECT
    room_name AS "Room",
    area AS "Area",
    user_name AS "User",
    days_in_row AS "Days in a row",
    TO_CHAR(series_start_date, 'YYYY-MM-DD') AS "Start date",
    TO_CHAR(series_end_date, 'YYYY-MM-DD') AS "End date",
    TO_CHAR(first_booking, 'HH24:MI') AS "Start time",
    TO_CHAR(last_booking, 'HH24:MI') AS "End time",
    avg_hours_per_day AS "Avg h/day",
    total_hours AS "Total hours",
    date_list AS "Dates in detail (hours)"
FROM consecutive_series
ORDER BY days_in_row DESC, total_hours DESC, series_start_date DESC
LIMIT 50;
