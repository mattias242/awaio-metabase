-- Dashboard 24: Booked lockers per day within a date range
-- Shows the number of unique lockers booked each day, total bookings and users
-- Useful for seeing utilisation over time and spotting peaks and troughs
-- Visualization: Line Chart (trend) or Column Chart (per day)
--
-- NOTE: Use the Metabase date filter to choose the period
-- Alternatively: change the WHERE clause to set specific dates

SELECT
    DATE(b.start_time) AS "Date",
    COUNT(DISTINCT b.entity_id) AS "Booked lockers",
    COUNT(b.id) AS "Bookings",
    COUNT(DISTINCT b.owner_id) AS "Users",
    -- Average booking duration per day
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Avg hours/booking",
    -- Total booked time per day
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  -- Change these dates or use a Metabase filter
  AND b.start_time >= '2025-01-01'::date
  AND b.start_time < '2025-12-31'::date + INTERVAL '1 day'
GROUP BY DATE(b.start_time)
ORDER BY DATE(b.start_time) ASC;
