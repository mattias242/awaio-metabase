-- Query 29: Weekly discovery trend per user
-- Shows how many NEW places users try each week over time
-- Measures the "discovery rate" - share of bookings at completely new places
-- NOTE: Works with both anonymised (User ABC123) and non-anonymised users
--
-- Metrics:
--   - New places: places the user has never used before (this week)
--   - Discovery rate: % of the week's bookings that are at new places
--   - Cumulative places: total unique places so far
--
-- Visualization: Line chart (week on the X axis, several metrics as lines)
-- Alternative: Stacked area chart to show progression

WITH user_weekly_bookings AS (
    -- All bookings grouped per user, week and place
    SELECT
        b.owner_id,
        COALESCE(u.name, 'User ' || b.owner_id) AS user_name,
        DATE_TRUNC('week', b.start_time) AS week,
        b.entity_id,
        e.name AS place_name,
        e.group_tag,
        COUNT(*) AS bookings,
        MIN(b.start_time) AS first_booking_of_week
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '12 weeks'  -- 12 weeks back
    GROUP BY b.owner_id, u.name, DATE_TRUNC('week', b.start_time), b.entity_id, e.name, e.group_tag
),
first_time_usage AS (
    -- Find the first time the user used each place (overall, not just per week)
    SELECT
        owner_id,
        entity_id,
        MIN(first_booking_of_week) AS first_time_ever
    FROM user_weekly_bookings
    GROUP BY owner_id, entity_id
),
weekly_discovery AS (
    -- Classify each place as "new" or "return visit" per week
    SELECT
        uwb.owner_id,
        uwb.user_name,
        uwb.week,
        uwb.entity_id,
        uwb.place_name,
        uwb.group_tag,
        uwb.bookings,
        CASE
            WHEN ftu.first_time_ever = uwb.week THEN 'new'
            ELSE 'return'
        END AS place_status
    FROM user_weekly_bookings uwb
    JOIN first_time_usage ftu ON uwb.owner_id = ftu.owner_id AND uwb.entity_id = ftu.entity_id
),
weekly_stats AS (
    -- Aggregate per user and week
    SELECT
        owner_id,
        user_name,
        week,
        COUNT(DISTINCT entity_id) AS places_week,
        COUNT(DISTINCT CASE WHEN place_status = 'new' THEN entity_id END) AS new_places_week,
        COUNT(DISTINCT CASE WHEN place_status = 'return' THEN entity_id END) AS return_visits_week,
        SUM(bookings) AS bookings_week,
        SUM(CASE WHEN place_status = 'new' THEN bookings ELSE 0 END) AS bookings_new_places,
        -- Discovery rate: % of bookings at new places
        ROUND(
            (SUM(CASE WHEN place_status = 'new' THEN bookings ELSE 0 END)::numeric /
             NULLIF(SUM(bookings), 0) * 100)::numeric,
            1
        ) AS discovery_rate_pct
    FROM weekly_discovery
    GROUP BY owner_id, user_name, week
),
cumulative_stats AS (
    -- Cumulative unique places over time
    SELECT
        owner_id,
        user_name,
        week,
        new_places_week,
        places_week,
        return_visits_week,
        bookings_week,
        bookings_new_places,
        discovery_rate_pct,
        -- Running total of unique places
        SUM(new_places_week) OVER (
            PARTITION BY owner_id
            ORDER BY week
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_unique_places
    FROM weekly_stats
)
-- Show data for the top 5 most mobile users
SELECT
    TO_CHAR(week, 'YYYY-WW') AS "Week",
    user_name AS "User",
    new_places_week AS "New places",
    return_visits_week AS "Return visits",
    places_week AS "Total places",
    cumulative_unique_places AS "Cumulative",
    discovery_rate_pct AS "Discovery %",
    bookings_week AS "Bookings"
FROM cumulative_stats
WHERE owner_id IN (
    -- Pick the top 5 users with the most new places in total
    SELECT owner_id
    FROM (
        SELECT owner_id, SUM(new_places_week) AS total_new
        FROM weekly_stats
        GROUP BY owner_id
        ORDER BY SUM(new_places_week) DESC
        LIMIT 5
    ) top_users
)
ORDER BY user_name, week;

-- ========================================
-- INSTRUCTIONS FOR METABASE
-- ========================================
--
-- VISUALIZATION 1: LINE CHART (Recommended)
-- 1. X axis: "Week"
-- 2. Y axis: "New places", "Discovery %", "Cumulative"
-- 3. Group by: "User"
-- 4. Shows: the trend over time for each user
-- 5. Insight: whether the discovery pace is rising or falling
--
-- VISUALIZATION 2: STACKED AREA CHART
-- 1. X axis: "Week"
-- 2. Y axis: "New places"
-- 3. Stack by: "User"
-- 4. Shows: total discovery in the organisation over time
--
-- TIPS:
-- - Change LIMIT 5 to show more or fewer users
-- - Filter on a specific user for a detailed view
-- - Add a filter for group_tag ('desk' or 'room')
-- - Export to CSV for trend analysis
