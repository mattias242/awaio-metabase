-- Dashboard 9b: Bookings per weekday compared - ROOMS (last 4 weeks vs the previous 4 weeks)
-- Shows bookings per weekday as two series for comparison
-- Excludes rooms in "Tillsammansytan"
-- Visualization: Grouped Bar Chart (Column chart with series)

WITH recent_period AS (
    -- Last 4 weeks
    SELECT
        CASE EXTRACT(DOW FROM b.start_time)
            WHEN 0 THEN '7-Sunday'
            WHEN 1 THEN '1-Monday'
            WHEN 2 THEN '2-Tuesday'
            WHEN 3 THEN '3-Wednesday'
            WHEN 4 THEN '4-Thursday'
            WHEN 5 THEN '5-Friday'
            WHEN 6 THEN '6-Saturday'
        END AS weekday,
        EXTRACT(DOW FROM b.start_time) AS dow_num,
        COUNT(*) AS cnt
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN entities parent ON e.parent_id = parent.id
    WHERE b.start_time >= NOW() - INTERVAL '4 weeks'
      AND b.start_time < NOW()
      AND e.group_tag = 'room'
      AND (parent.name IS NULL OR parent.name != 'Tillsammansytan')
    GROUP BY EXTRACT(DOW FROM b.start_time)
),
previous_period AS (
    -- Previous 4 weeks (weeks 5-8 back)
    SELECT
        CASE EXTRACT(DOW FROM b.start_time)
            WHEN 0 THEN '7-Sunday'
            WHEN 1 THEN '1-Monday'
            WHEN 2 THEN '2-Tuesday'
            WHEN 3 THEN '3-Wednesday'
            WHEN 4 THEN '4-Thursday'
            WHEN 5 THEN '5-Friday'
            WHEN 6 THEN '6-Saturday'
        END AS weekday,
        EXTRACT(DOW FROM b.start_time) AS dow_num,
        COUNT(*) AS cnt
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN entities parent ON e.parent_id = parent.id
    WHERE b.start_time >= NOW() - INTERVAL '8 weeks'
      AND b.start_time < NOW() - INTERVAL '4 weeks'
      AND e.group_tag = 'room'
      AND (parent.name IS NULL OR parent.name != 'Tillsammansytan')
    GROUP BY EXTRACT(DOW FROM b.start_time)
)
SELECT
    rp.weekday AS "Weekday",
    COALESCE(rp.cnt, 0) AS "Last 4 weeks",
    COALESCE(pp.cnt, 0) AS "Previous 4 weeks",
    ROUND(
        (CASE
            WHEN COALESCE(pp.cnt, 0) = 0 THEN 0
            ELSE ((COALESCE(rp.cnt, 0)::NUMERIC - COALESCE(pp.cnt, 0)) / COALESCE(pp.cnt, 0) * 100)
        END)::NUMERIC,
        1
    ) AS "Change %"
FROM recent_period rp
FULL OUTER JOIN previous_period pp ON rp.dow_num = pp.dow_num
ORDER BY COALESCE(rp.dow_num, pp.dow_num);
