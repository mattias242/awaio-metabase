-- Dashboard 25: Booked lockers per day - PARAMETERIZED VERSION
-- Shows the number of unique lockers booked each day, total bookings and users
-- Useful for seeing utilisation over time and spotting peaks and troughs
-- Visualization: Line Chart (trend) or Column Chart (per day)
--
-- METABASE PARAMETERS:
-- When you create this query in Metabase, add two "Field Filter" parameters:
--   1. Name: "start_date" → Type: Date → Default: 30 days ago
--   2. Name: "end_date" → Type: Date → Default: today
--
-- Metabase automatically replaces {{start_date}} and {{end_date}} with the chosen values

SELECT
    DATE(b.start_time) AS "Date",
    COUNT(DISTINCT b.entity_id) AS "Booked lockers",
    COUNT(b.id) AS "Bookings",
    COUNT(DISTINCT b.owner_id) AS "Users",
    -- Average booking duration per day
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Avg hours/booking",
    -- Total booked time per day
    ROUND(SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS "Total hours",
    -- Utilisation (share of all lockers)
    ROUND((COUNT(DISTINCT b.entity_id)::numeric /
           (SELECT COUNT(*) FROM entities WHERE group_tag = 'storage')::numeric * 100), 1) AS "% lockers used"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
  [[AND b.start_time >= {{start_date}}]]
  [[AND b.start_time < {{end_date}} + INTERVAL '1 day']]
GROUP BY DATE(b.start_time)
ORDER BY DATE(b.start_time) ASC;
