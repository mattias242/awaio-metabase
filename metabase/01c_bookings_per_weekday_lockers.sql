-- Dashboard 1c: Bookings per weekday - LOCKERS
-- Shows how many locker bookings are made on each day of the week
-- Visualization: Column chart

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
    COUNT(*) AS bookings,
    COUNT(DISTINCT b.entity_id) AS unique_lockers,
    COUNT(DISTINCT b.owner_id) AS unique_users
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'storage'
  AND b.status = 'reserved'
GROUP BY EXTRACT(DOW FROM b.start_time)
ORDER BY EXTRACT(DOW FROM b.start_time);
