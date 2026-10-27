-- Dashboard 11: Unbooked rooms
-- Shows rooms that have never been booked (unused resources)
-- Visualization: Table

SELECT
    e.name AS "Room",
    e.id AS entity_id,
    parent.name AS "Area",
    grandparent.name AS "Floor",
    e.created_at AS "Created",
    EXTRACT(DAYS FROM (NOW() - e.created_at)) AS "Days since created"
FROM entities e
LEFT JOIN bookings b ON e.id = b.entity_id
LEFT JOIN entities parent ON e.parent_id = parent.id
LEFT JOIN entities grandparent ON parent.parent_id = grandparent.id
WHERE e.group_tag = 'room'
  AND b.id IS NULL
ORDER BY e.created_at DESC;
