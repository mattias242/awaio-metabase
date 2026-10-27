-- Dashboard 18: Most mobile users - variation per day
-- Identifies users who book both a desk AND a room on the same day
-- Measures "mobility" as use of several kinds of place per day
-- NOTE: Works with both anonymised (User ABC123) and non-anonymised users
--
-- Score:
--   Score = (Days with both desk+room) + (Avg places/day)
--   Example: 15 days with both + 2.5 avg places/day = 17.5 score
--   Higher score = more mobile (more types and more places per day)
--
-- Visualization: Table or Horizontal Bar Chart (use # as X axis)

WITH daily_bookings AS (
    -- Group bookings per user and day
    -- NOTE: owner_id is Awaio's user_id (stable over time)
    -- u.name is either the real name or anonymised (User ABC123)
    SELECT
        b.owner_id,
        COALESCE(u.name, 'User ' || b.owner_id) AS user_name,  -- Fallback if the user is missing
        DATE(b.start_time) AS booking_date,
        e.group_tag,
        COUNT(DISTINCT b.entity_id) AS distinct_places,
        STRING_AGG(DISTINCT e.name, ', ' ORDER BY e.name) AS place_list
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')  -- Desks and rooms only
      AND b.start_time >= NOW() - INTERVAL '90 days'  -- Last 90 days
    GROUP BY b.owner_id, u.name, DATE(b.start_time), e.group_tag
),
daily_diversity AS (
    -- Count days where the user has both a desk AND a room
    SELECT
        owner_id,
        user_name,
        booking_date,
        COUNT(DISTINCT group_tag) AS type_count,  -- 1 = desk or room only, 2 = both
        SUM(CASE WHEN group_tag = 'desk' THEN distinct_places ELSE 0 END) AS desks_per_day,
        SUM(CASE WHEN group_tag = 'room' THEN distinct_places ELSE 0 END) AS rooms_per_day,
        SUM(distinct_places) AS places_per_day
    FROM daily_bookings
    GROUP BY owner_id, user_name, booking_date
),
user_stats AS (
    -- Aggregate statistics per user
    SELECT
        owner_id,
        user_name,
        COUNT(DISTINCT booking_date) AS booking_days,
        COUNT(DISTINCT CASE WHEN type_count = 2 THEN booking_date END) AS days_with_desk_and_room,
        ROUND(AVG(desks_per_day)::numeric, 1) AS avg_desks_per_day,
        ROUND(AVG(rooms_per_day)::numeric, 1) AS avg_rooms_per_day,
        ROUND(AVG(places_per_day)::numeric, 1) AS avg_places_per_day,
        MAX(places_per_day) AS max_places_one_day,
        -- "Mobility score": days with both types + avg places per day
        COUNT(DISTINCT CASE WHEN type_count = 2 THEN booking_date END) +
        ROUND(AVG(places_per_day)::numeric, 1) AS mobility_score
    FROM daily_diversity
    GROUP BY owner_id, user_name
    HAVING COUNT(DISTINCT booking_date) >= 5  -- At least 5 booking days to be relevant
)
SELECT
    ROW_NUMBER() OVER (ORDER BY days_with_desk_and_room DESC, avg_places_per_day DESC) AS "#",
    user_name AS "User",
    booking_days AS "Booking days",
    days_with_desk_and_room AS "Desk+room days",
    avg_desks_per_day AS "Avg desks/day",
    avg_rooms_per_day AS "Avg rooms/day",
    avg_places_per_day AS "Avg places/day",
    max_places_one_day AS "Max places",
    ROUND(mobility_score::numeric, 1) AS "Score"
FROM user_stats
ORDER BY days_with_desk_and_room DESC, avg_places_per_day DESC
LIMIT 10;
