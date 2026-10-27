-- Dashboard 5: Top 10 mest aktiva användare med deras 5 vanligaste skrivbord
-- Visar de 10 användare med flest bokningar och deras 5 mest bokade skrivbord
-- Visualisering: Table (pivot-format)

WITH user_desk_bookings AS (
    -- Räkna bokningar per användare och skrivbord
    SELECT
        u.email AS användare,
        COALESCE(u.name, SPLIT_PART(u.email, '@', 1)) AS användarnamn,
        e.name AS skrivbord,
        COUNT(b.id) AS antal_bokningar,
        ROW_NUMBER() OVER (PARTITION BY u.email ORDER BY COUNT(b.id) DESC) AS rank
    FROM booking_organizers bo
    JOIN users u ON bo.user_id = u.id
    JOIN bookings b ON bo.booking_id = b.id
    JOIN entities e ON b.entity_id = e.id
    WHERE e.group_tag = 'desk'
    GROUP BY u.email, u.name, e.name
),
top_users AS (
    -- Hitta de 10 mest aktiva användarna
    SELECT
        u.email AS användare,
        COALESCE(u.name, SPLIT_PART(u.email, '@', 1)) AS användarnamn,
        COUNT(DISTINCT b.id) AS totalt_antal_bokningar
    FROM booking_organizers bo
    JOIN users u ON bo.user_id = u.id
    JOIN bookings b ON bo.booking_id = b.id
    JOIN entities e ON b.entity_id = e.id
    WHERE e.group_tag = 'desk'
    GROUP BY u.email, u.name
    ORDER BY totalt_antal_bokningar DESC
    LIMIT 10
)
SELECT
    tu.användarnamn,
    tu.totalt_antal_bokningar,
    MAX(CASE WHEN udb.rank = 1 THEN udb.skrivbord || ' (' || udb.antal_bokningar || ')' END) AS "Skrivbord 1",
    MAX(CASE WHEN udb.rank = 2 THEN udb.skrivbord || ' (' || udb.antal_bokningar || ')' END) AS "Skrivbord 2",
    MAX(CASE WHEN udb.rank = 3 THEN udb.skrivbord || ' (' || udb.antal_bokningar || ')' END) AS "Skrivbord 3",
    MAX(CASE WHEN udb.rank = 4 THEN udb.skrivbord || ' (' || udb.antal_bokningar || ')' END) AS "Skrivbord 4",
    MAX(CASE WHEN udb.rank = 5 THEN udb.skrivbord || ' (' || udb.antal_bokningar || ')' END) AS "Skrivbord 5"
FROM top_users tu
LEFT JOIN user_desk_bookings udb ON tu.användare = udb.användare AND udb.rank <= 5
GROUP BY tu.användarnamn, tu.totalt_antal_bokningar
ORDER BY tu.totalt_antal_bokningar DESC;
