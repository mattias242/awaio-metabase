-- Dashboard 19: Most mobile users - unique places over time
-- Identifies users who use many different entities (never the same place)
-- Measures "mobility" as unique places per week and total variation
-- NOTE: Works with both anonymised (User ABC123) and non-anonymised users
--
-- Score:
--   Score = (Total unique places) / (Avg visits/place)
--   Example: 25 unique places / 2.3 visits per place = 10.9 score
--   Higher score = more mobile (many places, few return visits)
--   Lower score = more stationary (few places, many return visits)
--
-- Visualization: Scatter Plot (X = Unique places, Y = Visits/place, Size = Score)

WITH user_bookings AS (
    -- All bookings with week number
    -- NOTE: owner_id is Awaio's user_id (stable identifier)
    -- u.name is either the real name or anonymised (User ABC123)
    SELECT
        b.owner_id,
        COALESCE(u.name, 'User ' || b.owner_id) AS user_name,  -- Fallback if the user is missing
        b.entity_id,
        e.name AS place_name,
        e.group_tag,
        DATE(b.start_time) AS booking_date,
        DATE_TRUNC('week', b.start_time) AS week
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '90 days'
),
weekly_stats AS (
    -- Statistics per user and week
    SELECT
        owner_id,
        user_name,
        week,
        COUNT(DISTINCT entity_id) AS unique_places_week,
        COUNT(DISTINCT booking_date) AS booking_days_week,
        COUNT(DISTINCT CASE WHEN group_tag = 'desk' THEN entity_id END) AS unique_desks,
        COUNT(DISTINCT CASE WHEN group_tag = 'room' THEN entity_id END) AS unique_rooms
    FROM user_bookings
    GROUP BY owner_id, user_name, week
),
user_stats AS (
    -- Aggregate over all weeks
    SELECT
        owner_id,
        user_name,
        COUNT(DISTINCT week) AS weeks,
        SUM(booking_days_week) AS total_booking_days,
        ROUND(AVG(unique_places_week)::numeric, 1) AS avg_unique_places_per_week,
        MAX(unique_places_week) AS max_unique_places_one_week,
        ROUND(AVG(unique_desks)::numeric, 1) AS avg_unique_desks_per_week,
        ROUND(AVG(unique_rooms)::numeric, 1) AS avg_unique_rooms_per_week
    FROM weekly_stats
    GROUP BY owner_id, user_name
    HAVING SUM(booking_days_week) >= 5  -- At least 5 booking days in total
),
total_diversity AS (
    -- Total variation over the whole period
    SELECT
        owner_id,
        COUNT(DISTINCT entity_id) AS total_unique_places,
        COUNT(DISTINCT CASE WHEN group_tag = 'desk' THEN entity_id END) AS total_unique_desks,
        COUNT(DISTINCT CASE WHEN group_tag = 'room' THEN entity_id END) AS total_unique_rooms,
        -- How often the same place is used (lower = more variation)
        ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT entity_id), 0), 1) AS avg_visits_per_place
    FROM user_bookings
    GROUP BY owner_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY td.total_unique_places DESC, td.avg_visits_per_place ASC) AS "#",
    us.user_name AS "User",
    us.total_booking_days AS "Booking days",
    td.total_unique_places AS "Unique places",
    td.total_unique_desks AS "Unique desks",
    td.total_unique_rooms AS "Unique rooms",
    us.avg_unique_places_per_week AS "Avg/week",
    us.max_unique_places_one_week AS "Max/week",
    td.avg_visits_per_place AS "Visits/place",
    -- "Variation score": more unique places and fewer return visits = higher score
    ROUND((td.total_unique_places::numeric / NULLIF(td.avg_visits_per_place, 0))::numeric, 1) AS "Score"
FROM user_stats us
JOIN total_diversity td ON us.owner_id = td.owner_id
ORDER BY td.total_unique_places DESC, td.avg_visits_per_place ASC
LIMIT 10;
