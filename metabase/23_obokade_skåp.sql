-- Dashboard 23: Obokade skåp
-- Visar alla skåp som ALDRIG har bokats
-- Hjälper identifiera resurser som kan tas bort eller behöver marknadsföras
-- Visualisering: Table

SELECT
    e.name AS "Skåp",
    e.id AS entity_id,
    parent.name AS "Område",
    e.capacity_normal AS "Kapacitet (normal)",
    e.capacity_max AS "Kapacitet (max)",
    e.created_at AS "Skapad"
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
