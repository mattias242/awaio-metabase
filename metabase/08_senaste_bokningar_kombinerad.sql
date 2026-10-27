-- Dashboard 8: De 5 senaste bokningarna (skrivbord + rum kombinerat)
-- Visar de allra senaste bokningarna oavsett typ
-- Visualisering: Table

SELECT
    b.start_time AS "Starttid",
    CASE
        WHEN e.group_tag = 'desk' THEN '🖥️ Skrivbord'
        WHEN e.group_tag = 'room' THEN '🏢 Rum'
        WHEN e.group_tag = 'storage' THEN '🔒 Skåp'
        ELSE e.group_tag
    END AS "Typ",
    e.name AS "Resurs",
    parent.name AS "Område",
    u.email AS "Bokad av",
    ROUND(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600, 1) AS "Timmar",
    CASE
        WHEN b.cancelled THEN '❌ Avbokad'
        WHEN b.end_time < NOW() THEN '✅ Avslutad'
        WHEN b.start_time > NOW() THEN '🕐 Kommande'
        ELSE '▶️ Pågående'
    END AS "Status",
    b.created_at AS "Bokad när"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN booking_organizers bo ON b.id = bo.booking_id
LEFT JOIN users u ON bo.user_id = u.id
WHERE e.group_tag IN ('desk', 'room', 'storage')
ORDER BY b.created_at DESC
LIMIT 5;
