-- Metabase Query: Team Room Bookings by Weekday (Last 4 Weeks vs Previous 4 Weeks)
--
-- Shows bookings per Teams room and weekday
-- Compares the last 4 weeks with the 4 weeks before
--
-- For Metabase: use as a Native Query with Table visualization
-- NOTE: Pivot tables only work with the Question Builder, not native SQL
-- This query returns a plain table that is easy to read and filter

WITH date_ranges AS (
  -- Define the time periods
  SELECT
    CURRENT_DATE - INTERVAL '28 days' AS current_period_start,
    CURRENT_DATE AS current_period_end,
    CURRENT_DATE - INTERVAL '56 days' AS previous_period_start,
    CURRENT_DATE - INTERVAL '28 days' AS previous_period_end
),

room_bookings AS (
  -- Fetch all Teams room bookings
  SELECT
    e.name AS room_name,
    e.id AS entity_id,
    b.id AS booking_id,
    b.start_time,
    b.end_time,
    -- Extract weekday (1 = Monday, 7 = Sunday)
    EXTRACT(ISODOW FROM b.start_time) AS weekday_num,
    CASE EXTRACT(ISODOW FROM b.start_time)
      WHEN 1 THEN 'Monday'
      WHEN 2 THEN 'Tuesday'
      WHEN 3 THEN 'Wednesday'
      WHEN 4 THEN 'Thursday'
      WHEN 5 THEN 'Friday'
      WHEN 6 THEN 'Saturday'
      WHEN 7 THEN 'Sunday'
    END AS weekday_name,
    -- Work out which period the booking belongs to
    CASE
      WHEN b.start_time >= (SELECT current_period_start FROM date_ranges)
           AND b.start_time < (SELECT current_period_end FROM date_ranges)
      THEN 'current'
      WHEN b.start_time >= (SELECT previous_period_start FROM date_ranges)
           AND b.start_time < (SELECT previous_period_end FROM date_ranges)
      THEN 'previous'
      ELSE NULL
    END AS period
  FROM entities e
  INNER JOIN bookings b ON e.id = b.entity_id
  WHERE
    -- Teams rooms only (rooms, not desks or lockers)
    e.group_tag = 'room'
    AND b.status = 'reserved'
    -- Last 8 weeks
    AND b.start_time >= (SELECT previous_period_start FROM date_ranges)
    AND b.start_time < (SELECT current_period_end FROM date_ranges)
    -- Exclude weekends (optional)
    AND EXTRACT(ISODOW FROM b.start_time) BETWEEN 1 AND 5
)

-- Aggregate per room and weekday
SELECT
  room_name AS "Room",
  weekday_name AS "Weekday",
  COUNT(CASE WHEN period = 'current' THEN 1 END) AS "Last 4 weeks",
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Previous 4 weeks",
  COUNT(CASE WHEN period = 'current' THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Change",
  CASE
    WHEN COUNT(CASE WHEN period = 'previous' THEN 1 END) > 0 THEN
      ROUND(
        (COUNT(CASE WHEN period = 'current' THEN 1 END)::DECIMAL -
         COUNT(CASE WHEN period = 'previous' THEN 1 END)::DECIMAL) /
        COUNT(CASE WHEN period = 'previous' THEN 1 END)::DECIMAL * 100,
        1
      )
    ELSE NULL
  END AS "Change %"
FROM room_bookings
WHERE period IS NOT NULL
GROUP BY room_name, weekday_name, weekday_num
ORDER BY room_name, weekday_num;

-- ========================================
-- ALTERNATIVE QUERY: PIVOTED TABLE
-- ========================================
-- Weekdays as columns - easier to read per room
-- Remove the comment markers to use this query instead

/*
WITH date_ranges AS (
  SELECT
    CURRENT_DATE - INTERVAL '28 days' AS current_period_start,
    CURRENT_DATE AS current_period_end,
    CURRENT_DATE - INTERVAL '56 days' AS previous_period_start,
    CURRENT_DATE - INTERVAL '28 days' AS previous_period_end
),
room_bookings AS (
  SELECT
    e.name AS room_name,
    EXTRACT(ISODOW FROM b.start_time) AS weekday_num,
    CASE
      WHEN b.start_time >= (SELECT current_period_start FROM date_ranges)
           AND b.start_time < (SELECT current_period_end FROM date_ranges)
      THEN 'current'
      WHEN b.start_time >= (SELECT previous_period_start FROM date_ranges)
           AND b.start_time < (SELECT previous_period_end FROM date_ranges)
      THEN 'previous'
      ELSE NULL
    END AS period
  FROM entities e
  INNER JOIN bookings b ON e.id = b.entity_id
  WHERE
    e.group_tag = 'room'
    AND b.status = 'reserved'
    AND b.start_time >= (SELECT previous_period_start FROM date_ranges)
    AND b.start_time < (SELECT current_period_end FROM date_ranges)
    AND EXTRACT(ISODOW FROM b.start_time) BETWEEN 1 AND 5
)
SELECT
  room_name AS "Room",
  -- Monday
  COUNT(CASE WHEN period = 'current' AND weekday_num = 1 THEN 1 END) AS "Mon (now)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 1 THEN 1 END) AS "Mon (prev 4w)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 1 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 1 THEN 1 END) AS "Mon Δ",
  -- Tuesday
  COUNT(CASE WHEN period = 'current' AND weekday_num = 2 THEN 1 END) AS "Tue (now)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 2 THEN 1 END) AS "Tue (prev 4w)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 2 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 2 THEN 1 END) AS "Tue Δ",
  -- Wednesday
  COUNT(CASE WHEN period = 'current' AND weekday_num = 3 THEN 1 END) AS "Wed (now)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 3 THEN 1 END) AS "Wed (prev 4w)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 3 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 3 THEN 1 END) AS "Wed Δ",
  -- Thursday
  COUNT(CASE WHEN period = 'current' AND weekday_num = 4 THEN 1 END) AS "Thu (now)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 4 THEN 1 END) AS "Thu (prev 4w)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 4 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 4 THEN 1 END) AS "Thu Δ",
  -- Friday
  COUNT(CASE WHEN period = 'current' AND weekday_num = 5 THEN 1 END) AS "Fri (now)",
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 5 THEN 1 END) AS "Fri (prev 4w)",
  COUNT(CASE WHEN period = 'current' AND weekday_num = 5 THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' AND weekday_num = 5 THEN 1 END) AS "Fri Δ",
  -- Totals
  COUNT(CASE WHEN period = 'current' THEN 1 END) AS "Total (now)",
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Total (prev 4w)",
  COUNT(CASE WHEN period = 'current' THEN 1 END) -
  COUNT(CASE WHEN period = 'previous' THEN 1 END) AS "Total Δ"
FROM room_bookings
WHERE period IS NOT NULL
GROUP BY room_name
ORDER BY room_name;
*/

-- ========================================
-- INSTRUCTIONS FOR METABASE
-- ========================================
--
-- OPTION 1: TABLE WITH ONE ROW PER ROOM AND WEEKDAY (RECOMMENDED)
-- 1. Create a new question in Metabase
-- 2. Choose "Native Query" (SQL)
-- 3. Paste the main query above
-- 4. Save as "Teams rooms - Bookings per weekday"
-- 5. Visualization → Table
-- 6. Sort on "Change %" to see the biggest differences
-- 7. Use conditional formatting:
--    - "Change" > 0 → Green
--    - "Change" < 0 → Red
--
-- OPTION 2: PIVOTED TABLE WITH WEEKDAYS AS COLUMNS
-- 1. Use the alternative query above (remove the comment markers)
-- 2. Each weekday becomes its own column
-- 3. Easier to compare the same room across weekdays
-- 4. Better for printing and overview analysis
--
-- TIPS:
-- - Add a filter for specific rooms
-- - Build a dashboard with both options
-- - Export to CSV for further analysis in Excel
