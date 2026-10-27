-- Dashboard 1a: Bokningar per veckodag - SKRIVBORD
-- Visar hur många skrivbordsbokningar som görs varje dag i veckan
-- Visualisering: Column chart (stapeldiagram)

SELECT
    CASE EXTRACT(DOW FROM b.start_time)
        WHEN 0 THEN '7-Söndag'
        WHEN 1 THEN '1-Måndag'
        WHEN 2 THEN '2-Tisdag'
        WHEN 3 THEN '3-Onsdag'
        WHEN 4 THEN '4-Torsdag'
        WHEN 5 THEN '5-Fredag'
        WHEN 6 THEN '6-Lördag'
    END AS veckodag,
    COUNT(*) AS antal_bokningar,
    COUNT(DISTINCT b.entity_id) AS antal_unika_skrivbord,
    COUNT(DISTINCT b.owner_id) AS antal_unika_användare
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'desk'
  AND b.status = 'reserved'
GROUP BY EXTRACT(DOW FROM b.start_time)
ORDER BY EXTRACT(DOW FROM b.start_time);
