-- Dashboard 6: De 5 senaste bokade skrivborden
-- Visar de senaste skrivbordsbokningarna i realtid
-- Visualisering: Table

SELECT
    b.start_time AS "Starttid",
    e.name AS "Skrivbord",
    parent.name AS "Område",
    u.email AS "Bokad av",
    EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 AS "Timmar",
    CASE
        WHEN b.cancelled THEN 'Avbokad'
        WHEN b.end_time < NOW() THEN 'Avslutad'
        WHEN b.start_time > NOW() THEN 'Kommande'
        ELSE 'Pågående'
    END AS "Status",
    b.created_at AS "Bokad när"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN booking_organizers bo ON b.id = bo.booking_id
LEFT JOIN users u ON bo.user_id = u.id
WHERE e.group_tag = 'desk'
ORDER BY b.created_at DESC
LIMIT 5;
