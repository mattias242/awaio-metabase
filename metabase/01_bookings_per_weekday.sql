-- Dashboard 1: Bookings per weekday
-- Shows how many bookings are made on each day of the week
-- Visualization: Column chart

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
    COUNT(*) AS bookings
FROM bookings
GROUP BY EXTRACT(DOW FROM start_time)
ORDER BY EXTRACT(DOW FROM start_time);
