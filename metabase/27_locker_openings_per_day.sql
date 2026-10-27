-- Dashboard 27: Locker openings per day within a date range
-- Shows how many times lockers are opened (bookings) each day, number of users and lockers
-- Focuses on OPENINGS (number of bookings) rather than unique lockers
-- Visualization: Line Chart (trend) or Column Chart (per day)
--
-- NOTE: Use the Metabase date filter to choose the period
-- Alternatively: change the WHERE clause to set specific dates

SELECT
    DATE(b.start_time) AS "Date",
    COUNT(b.id) AS "Openings",  -- Bookings = times a locker is opened
    COUNT(DISTINCT b.entity_id) AS "Distinct lockers",  -- How many lockers were used
    COUNT(DISTINCT b.owner_id) AS "Users",  -- How many people
    -- Average booking duration per opening
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Avg hours/opening",
    -- Total booked time per day
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours",
    -- Average openings per locker
    ROUND(COUNT(b.id)::numeric / NULLIF(COUNT(DISTINCT b.entity_id), 0), 1) AS "Openings/locker"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  -- Change these dates or use a Metabase filter
  AND b.start_time >= '2025-01-01'::date
  AND b.start_time < '2025-12-31'::date + INTERVAL '1 day'
GROUP BY DATE(b.start_time)
ORDER BY DATE(b.start_time) ASC;
