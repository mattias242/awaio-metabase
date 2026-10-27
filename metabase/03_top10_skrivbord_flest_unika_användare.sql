-- Dashboard 3: Top 10 skrivbord med flest unika användare
-- Visar de 10 skrivbord som flest olika personer har testat
-- Visualisering: Horizontal bar chart eller Table

SELECT
    e.name AS skrivbord,
    e.id AS entity_id,
    COUNT(DISTINCT bo.user_id) AS antal_unika_användare,
    COUNT(b.id) AS totalt_antal_bokningar,
    e.parent_id,
    parent.name AS område
FROM bookings b
JOIN entities e ON b.entity_id = e.id
LEFT JOIN entities parent ON e.parent_id = parent.id
JOIN booking_organizers bo ON b.id = bo.booking_id
WHERE e.group_tag = 'desk'
GROUP BY e.id, e.name, e.parent_id, parent.name
ORDER BY antal_unika_användare DESC
LIMIT 10;
