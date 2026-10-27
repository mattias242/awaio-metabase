-- Dashboard 13: Obokade skrivbord
-- Visar skrivbord som aldrig har bokats (outnyttjade resurser)
-- Visualisering: Table

SELECT
    e.name AS "Skrivbord",
    e.id AS entity_id,
    parent.name AS "Område",
    grandparent.name AS "Våning",
    e.created_at AS "Skapad datum",
    EXTRACT(DAYS FROM (NOW() - e.created_at)) AS "Dagar sedan skapad"
FROM entities e
LEFT JOIN bookings b ON e.id = b.entity_id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN entities grandparent ON parent.parent_id = grandparent.id
WHERE e.group_tag = 'desk'
  AND b.id IS NULL
ORDER BY e.created_at DESC;
