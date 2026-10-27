-- Dashboard 23: Unbooked lockers
-- Shows all lockers that have NEVER been booked
-- Helps identify resources that can be removed or need promoting
-- Visualization: Table

SELECT
    e.name AS "Locker",
    e.id AS entity_id,
    parent.name AS "Area",
    e.capacity_normal AS "Capacity (normal)",
    e.capacity_max AS "Capacity (max)",
    e.created_at AS "Created"
FROM entities e
LEFT JOIN entities parent ON e.parent_id = parent.id
WHERE e.group_tag = 'storage'
  AND NOT EXISTS (
      SELECT 1
      FROM bookings b
      WHERE b.entity_id = e.id
        AND b.status = 'reserved'
  )
ORDER BY parent.name, e.name;
