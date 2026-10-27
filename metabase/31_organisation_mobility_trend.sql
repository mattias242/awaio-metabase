-- Query 31: Organisation mobility over time
-- Shows how the organisation as a whole moves between places week by week
-- Measures the "mobility culture" - whether users dare to vary their workplaces
--
-- Metrics:
--   - Active users: users who booked anything this week
--   - Avg places/user: average number of unique places per user
--   - Mobile users %: share of users who used 2+ places
--   - Total unique places: number of distinct places used in the organisation
--   - Place diversity: total places / active users (higher = more spread)
--
-- Visualization: Line chart with several metrics over time
-- Alternative: Dual-axis chart (volume on the left, % on the right)

WITH weekly_user_mobility AS (
    -- Mobility per user and week
    SELECT
        DATE_TRUNC('week', b.start_time) AS week,
        b.owner_id,
        COALESCE(u.name, 'User ' || b.owner_id) AS user_name,
        COUNT(DISTINCT b.entity_id) AS unique_places_user,
        COUNT(*) AS bookings_user,
        -- Classify the user as mobile (2+ places) or stationary (1 place)
        CASE
            WHEN COUNT(DISTINCT b.entity_id) >= 2 THEN 'mobile'
            ELSE 'stationary'
        END AS mobility_class
    FROM bookings b
    LEFT JOIN users u ON b.owner_id = u.id
    JOIN entities e ON b.entity_id = e.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '12 weeks'
    GROUP BY DATE_TRUNC('week', b.start_time), b.owner_id, u.name
),
weekly_org_stats AS (
    -- Aggregate at organisation level per week
    SELECT
        week,
        COUNT(DISTINCT owner_id) AS active_users,
        COUNT(DISTINCT CASE WHEN mobility_class = 'mobile' THEN owner_id END) AS mobile_users,
        ROUND(AVG(unique_places_user)::numeric, 1) AS avg_places_per_user,
        SUM(bookings_user) AS total_bookings,
        -- Total unique places for the whole organisation
        (
            SELECT COUNT(DISTINCT entity_id)
            FROM bookings b2
            JOIN entities e2 ON b2.entity_id = e2.id
            WHERE b2.status = 'reserved'
              AND e2.group_tag IN ('desk', 'room')
              AND DATE_TRUNC('week', b2.start_time) = wum.week
        ) AS total_unique_places,
        -- Percentage of mobile users
        ROUND(
            (COUNT(DISTINCT CASE WHEN mobility_class = 'mobile' THEN owner_id END)::numeric /
             NULLIF(COUNT(DISTINCT owner_id), 0) * 100)::numeric,
            1
        ) AS mobile_pct
    FROM weekly_user_mobility wum
    GROUP BY week
),
weekly_diversity AS (
    -- Place diversity (spread across the organisation)
    SELECT
        week,
        active_users,
        mobile_users,
        mobile_pct,
        avg_places_per_user,
        total_unique_places,
        total_bookings,
        -- Diversity index: places per active user
        ROUND(
            (total_unique_places::numeric / NULLIF(active_users, 0))::numeric,
            2
        ) AS place_diversity,
        -- Moving average to show trends (3-week average)
        ROUND(
            AVG(avg_places_per_user) OVER (
                ORDER BY week
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )::numeric,
            1
        ) AS avg_places_trend_3w,
        ROUND(
            AVG(mobile_pct) OVER (
                ORDER BY week
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )::numeric,
            1
        ) AS mobile_pct_trend_3w
    FROM weekly_org_stats
)
-- Main query: organisation mobility over time
SELECT
    TO_CHAR(week, 'YYYY-WW') AS "Week",
    active_users AS "Active users",
    mobile_users AS "Mobile users",
    mobile_pct AS "Mobile %",
    avg_places_per_user AS "Avg places/user",
    total_unique_places AS "Total places",
    place_diversity AS "Place diversity",
    total_bookings AS "Bookings",
    avg_places_trend_3w AS "Places trend (3w)",
    mobile_pct_trend_3w AS "Mobile % trend (3w)"
FROM weekly_diversity
ORDER BY week;

-- ========================================
-- INSTRUCTIONS FOR METABASE
-- ========================================
--
-- VISUALIZATION 1: LINE CHART (Recommended)
-- 1. X axis: "Week"
-- 2. Y axis (left): "Avg places/user", "Places trend (3w)"
-- 3. Y axis (right): "Mobile %", "Mobile % trend (3w)"
-- 4. Shows: trends in the organisation's mobility over time
-- 5. Insight: whether mobility is rising or falling
--
-- VISUALIZATION 2: DUAL-AXIS CHART
-- 1. X axis: "Week"
-- 2. Y axis (left): "Active users", "Mobile users"
-- 3. Y axis (right): "Mobile %"
-- 4. Shows: volume and share of mobile users
--
-- VISUALIZATION 3: STACKED AREA CHART
-- 1. X axis: "Week"
-- 2. Y axis: "Mobile users" and stationary users (active - mobile)
-- 3. Stack: show the share
-- 4. Insight: visual split over time
--
-- VISUALIZATION 4: TABLE
-- 1. Sort on "Week" (descending) to see the latest first
-- 2. Conditional formatting:
--    - "Mobile %" >= 60 → Green
--    - "Mobile %" < 40 → Red
-- 3. Focus on the trend columns to see the direction
--
-- TIPS:
-- - Place diversity > 1.5 indicates a good spread across the organisation
-- - Compare "Avg places/user" with "Places trend (3w)" to see whether it is rising
-- - Combine with Query 29 (per user) to identify specific users
-- - Export to CSV for long-term trend analysis
-- - Change the period (NOW() - INTERVAL '12 weeks') for a longer or shorter analysis
-- - Filter on specific group_tags ('desk' vs 'room') for detailed analysis
--
-- METRIC DEFINITIONS:
-- - Mobile user: uses 2+ different places per week
-- - Stationary user: uses only 1 place per week
-- - Place diversity: total unique places / active users (a measure of spread)
-- - Trend (3w): 3-week moving average to filter out noise
