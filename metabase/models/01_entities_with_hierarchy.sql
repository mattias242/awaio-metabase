-- Model: Entities with hierarchy
-- Flattens the 4-level entity tree (Building → Floor → Area → Resource) so
-- floor_name and area_name are available as plain columns. Used internally
-- by bookings_enriched and queryable on its own.

SELECT
    e.id                    AS entity_id,
    e.name                  AS entity_name,
    e.group_tag             AS group_tag,
    e.main_tag              AS main_tag,
    e.community_id          AS community_id,
    e.capacity_normal       AS capacity_normal,
    e.capacity_max          AS capacity_max,
    parent.id               AS area_id,
    parent.name             AS area_name,
    grandparent.id          AS floor_id,
    grandparent.name        AS floor_name,
    grandparent.parent_id   AS building_id
FROM entities e
LEFT JOIN entities parent       ON e.parent_id       = parent.id
LEFT JOIN entities grandparent  ON parent.parent_id  = grandparent.id
