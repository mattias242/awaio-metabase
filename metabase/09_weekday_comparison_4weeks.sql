-- Dashboard 9: Bookings per weekday compared (last 4 weeks vs the previous 4 weeks)
-- Shows bookings per weekday as two series for comparison
-- Visualization: Grouped Bar Chart (Column chart with series)

WITH weekdays AS (
    -- Generate all weekdays
    SELECT
        dow,
        CASE dow
            WHEN 0 THEN '7-Sunday'
            WHEN 1 THEN '1-Monday'
            WHEN 2 THEN '2-Tuesday'
            WHEN 3 THEN '3-Wednesday'
            WHEN 4 THEN '4-Thursday'
            WHEN 5 THEN '5-Friday'
            WHEN 6 THEN '6-Saturday'
        END AS weekday
    FROM generate_series(0, 6) AS dow
),
recent_period AS (
    -- Last 4 weeks
    SELECT
        CASE EXTRACT(DOW FROM start_time)
            WHEN 0 THEN '7-Sunday'
            WHEN 1 THEN '1-Monday'
            WHEN 2 THEN '2-Tuesday'
            WHEN 3 THEN '3-Wednesday'
            WHEN 4 THEN '4-Thursday'
            WHEN 5 THEN '5-Friday'
            WHEN 6 THEN '6-Saturday'
        END AS weekday,
        EXTRACT(DOW FROM start_time) AS dow_num,
        COUNT(*) AS cnt
    FROM bookings
    WHERE start_time >= NOW() - INTERVAL '4 weeks'
      AND start_time < NOW()
    GROUP BY EXTRACT(DOW FROM start_time)
),
previous_period AS (
    -- Previous 4 weeks (weeks 5-8 back)
    SELECT
        CASE EXTRACT(DOW FROM start_time)
            WHEN 0 THEN '7-Sunday'
            WHEN 1 THEN '1-Monday'
            WHEN 2 THEN '2-Tuesday'
            WHEN 3 THEN '3-Wednesday'
            WHEN 4 THEN '4-Thursday'
            WHEN 5 THEN '5-Friday'
            WHEN 6 THEN '6-Saturday'
        END AS weekday,
        EXTRACT(DOW FROM start_time) AS dow_num,
        COUNT(*) AS cnt
    FROM bookings
    WHERE start_time >= NOW() - INTERVAL '8 weeks'
      AND start_time < NOW() - INTERVAL '4 weeks'
    GROUP BY EXTRACT(DOW FROM start_time)
)
SELECT
    wd.weekday AS "Weekday",
    COALESCE(rp.cnt, 0) AS "Last 4 weeks",
    COALESCE(pp.cnt, 0) AS "Previous 4 weeks",
    ROUND(
        (CASE
            WHEN COALESCE(pp.cnt, 0) = 0 THEN 0
            ELSE ((COALESCE(rp.cnt, 0)::NUMERIC - COALESCE(pp.cnt, 0)) / COALESCE(pp.cnt, 0) * 100)
        END)::NUMERIC,
        1
    ) AS "Change %"
FROM weekdays wd
LEFT JOIN recent_period rp ON wd.dow = rp.dow_num
LEFT JOIN previous_period pp ON wd.dow = pp.dow_num
ORDER BY wd.dow;
