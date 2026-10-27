-- Dashboard 1: Bokningar per veckodag
-- Visar hur många bokningar som görs varje dag i veckan
-- Visualisering: Column chart (stapeldiagram)

SELECT
    CASE EXTRACT(DOW FROM start_time)
        WHEN 0 THEN '7-Söndag'
        WHEN 1 THEN '1-Måndag'
        WHEN 2 THEN '2-Tisdag'
        WHEN 3 THEN '3-Onsdag'
        WHEN 4 THEN '4-Torsdag'
        WHEN 5 THEN '5-Fredag'
        WHEN 6 THEN '6-Lördag'
    END AS veckodag,
    COUNT(*) AS antal_bokningar
FROM bookings
GROUP BY EXTRACT(DOW FROM start_time)
ORDER BY EXTRACT(DOW FROM start_time);
