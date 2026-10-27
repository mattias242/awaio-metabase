-- Model: User weekly mobility
-- One row per (week_start, user). Captures how many different entities,
-- desks and rooms a user visits each week — foundation for mobility /
-- discovery dashboards.

SELECT
    week_start,
    owner_id,
    user_display_name,
    COUNT(DISTINCT entity_id)                                            AS unique_entities,
    COUNT(DISTINCT CASE WHEN entity_group_tag = 'desk'   THEN entity_id END) AS unique_desks,
    COUNT(DISTINCT CASE WHEN entity_group_tag = 'room'   THEN entity_id END) AS unique_rooms,
    COUNT(DISTINCT CASE WHEN entity_group_tag = 'locker' THEN entity_id END) AS unique_lockers,
    COUNT(DISTINCT floor_id)                                             AS unique_floors,
    COUNT(DISTINCT booking_date)                                         AS days_with_bookings,
    COUNT(*)                                                             AS total_bookings,
    SUM(duration_hours)::numeric(10,2)                                   AS total_hours
FROM {{@model:bookings_enriched}}
GROUP BY 1,2,3
