-- Model: Daily entity metrics
-- One row per (booking_date, entity). Pre-aggregates the per-day-per-entity
-- numbers used by desk/room/locker trend queries.

SELECT
    booking_date,
    entity_id,
    entity_name,
    entity_group_tag,
    entity_main_tag,
    floor_id,
    floor_name,
    area_id,
    area_name,
    COUNT(*)                                   AS bookings,
    COUNT(DISTINCT owner_id)                   AS unique_users,
    SUM(duration_hours)::numeric(10,2)         AS total_hours,
    AVG(duration_hours)::numeric(10,2)         AS avg_duration_hours,
    MIN(start_time)                            AS first_booking_at,
    MAX(end_time)                              AS last_booking_at
FROM {{@model:bookings_enriched}}
GROUP BY 1,2,3,4,5,6,7,8,9
