-- Model: Bookings enriched
-- Flat fact table with all joins, filters and computed fields pre-applied.
-- Drives most dashboard questions. Excludes cancelled and non-reserved bookings.

SELECT
    b.id                                                           AS booking_id,
    b.owner_id                                                     AS owner_id,
    u.display_name                                                 AS user_display_name,
    u.email                                                        AS user_email,
    b.start_time                                                   AS start_time,
    b.end_time                                                     AS end_time,
    DATE(b.start_time)                                             AS booking_date,
    DATE_TRUNC('week', b.start_time)::date                         AS week_start,
    EXTRACT(DOW FROM b.start_time)::int                            AS weekday_num,
    TO_CHAR(b.start_time, 'FMDay')                                 AS weekday_name,
    EXTRACT(HOUR FROM b.start_time)::int                           AS hour_of_day,
    (EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600.0)::numeric(10,2)
                                                                   AS duration_hours,
    b.status                                                       AS status,
    b.cancelled                                                    AS cancelled,
    b.ended_early                                                  AS ended_early,
    b.is_admin                                                     AS is_admin,
    b.group_tag                                                    AS booking_group_tag,
    b.main_tag                                                     AS booking_main_tag,
    b.category                                                     AS category,
    b.community_id                                                 AS community_id,
    e.id                                                           AS entity_id,
    e.name                                                         AS entity_name,
    e.group_tag                                                    AS entity_group_tag,
    e.main_tag                                                     AS entity_main_tag,
    parent.id                                                      AS area_id,
    parent.name                                                    AS area_name,
    grandparent.id                                                 AS floor_id,
    grandparent.name                                               AS floor_name,
    e.capacity_normal                                              AS capacity_normal,
    e.capacity_max                                                 AS capacity_max
FROM bookings b
JOIN entities e                 ON b.entity_id       = e.id
LEFT JOIN entities parent       ON e.parent_id       = parent.id
LEFT JOIN entities grandparent  ON parent.parent_id  = grandparent.id
LEFT JOIN users u               ON b.owner_id        = u.id
WHERE b.status = 'reserved'
  AND b.cancelled = FALSE
