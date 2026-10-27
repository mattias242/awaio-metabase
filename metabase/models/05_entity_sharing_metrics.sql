-- Model: Entity sharing metrics
-- One row per entity, summarising how many distinct users it serves, total
-- volume and how dominated it is by its top user (top_user_share close to 1
-- means one person monopolises that resource).

WITH per_user AS (
    SELECT
        entity_id,
        entity_name,
        entity_group_tag,
        floor_name,
        area_name,
        owner_id,
        COUNT(*) AS user_bookings
    FROM {{@model:bookings_enriched}}
    GROUP BY 1,2,3,4,5,6
)
SELECT
    entity_id,
    entity_name,
    entity_group_tag,
    floor_name,
    area_name,
    COUNT(DISTINCT owner_id)                                             AS unique_users,
    SUM(user_bookings)                                                   AS total_bookings,
    MAX(user_bookings)                                                   AS top_user_bookings,
    (MAX(user_bookings)::numeric / NULLIF(SUM(user_bookings), 0))::numeric(10,3)
                                                                         AS top_user_share
FROM per_user
GROUP BY 1,2,3,4,5
