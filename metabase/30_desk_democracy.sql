-- Query 30: Desk democracy (desk sharing & diversity)
-- Shows which desks are shared by many users vs dominated by a single user
-- Measures the "democracy level" - how evenly use is spread
--
-- Metrics:
--   - Total users: number of unique users who have used the desk
--   - Dominance ratio: the top user's share of all bookings (%)
--   - Democracy score: 100 - dominance_ratio (higher = more evenly shared)
--   - Top user: the user with the most bookings
--
-- Visualization: Scatter plot (X = Total users, Y = Democracy score, Size = Total bookings)
-- Alternative: Horizontal bar chart sorted on democracy score

WITH desk_bookings AS (
    -- All desk bookings in the last 12 weeks
    SELECT
        b.entity_id,
        e.name AS desk,
        b.owner_id,
        COALESCE(u.name, 'User ' || b.owner_id) AS user_name,
        COUNT(*) AS bookings
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag = 'desk'
      AND b.start_time >= NOW() - INTERVAL '12 weeks'
    GROUP BY b.entity_id, e.name, b.owner_id, u.name
),
desk_stats AS (
    -- Aggregate statistics per desk
    SELECT
        entity_id,
        desk,
        COUNT(DISTINCT owner_id) AS total_users,
        SUM(bookings) AS total_bookings,
        -- Find the top user and their share
        MAX(bookings) AS max_bookings_one_user,
        ROUND(
            (MAX(bookings)::numeric / NULLIF(SUM(bookings), 0) * 100)::numeric,
            1
        ) AS dominance_ratio,
        -- Democracy score: 100 = perfectly even, 0 = one user dominates completely
        ROUND(
            (100 - (MAX(bookings)::numeric / NULLIF(SUM(bookings), 0) * 100))::numeric,
            1
        ) AS democracy_score
    FROM desk_bookings
    GROUP BY entity_id, desk
),
top_users AS (
    -- Find the name of the top user per desk
    SELECT DISTINCT ON (entity_id)
        entity_id,
        user_name AS top_user,
        bookings AS top_user_bookings
    FROM desk_bookings
    ORDER BY entity_id, bookings DESC
)
-- Main query: all desks with democracy metrics
SELECT
    ds.desk AS "Desk",
    ds.total_users AS "Total users",
    tu.top_user AS "Top user",
    tu.top_user_bookings AS "Top bookings",
    ds.dominance_ratio AS "Dominance %",
    ds.democracy_score AS "Democracy score",
    ds.total_bookings AS "Total bookings",
    -- Category for classification
    CASE
        WHEN ds.democracy_score >= 80 THEN 'Highly shared'
        WHEN ds.democracy_score >= 60 THEN 'Shared'
        WHEN ds.democracy_score >= 40 THEN 'Moderately shared'
        WHEN ds.democracy_score >= 20 THEN 'Rarely shared'
        ELSE 'Private/Dominated'
    END AS "Category"
FROM desk_stats ds
JOIN top_users tu ON ds.entity_id = tu.entity_id
WHERE ds.total_bookings >= 5  -- Desks with at least 5 bookings
ORDER BY ds.democracy_score DESC, ds.total_users DESC;

-- ========================================
-- INSTRUCTIONS FOR METABASE
-- ========================================
--
-- VISUALIZATION 1: SCATTER PLOT (Recommended)
-- 1. X axis: "Total users"
-- 2. Y axis: "Democracy score"
-- 3. Size/Bubble: "Total bookings"
-- 4. Color: "Category"
-- 5. Insight: desks in the top right corner are the most democratic and most used
--
-- VISUALIZATION 2: HORIZONTAL BAR CHART
-- 1. Y axis: "Desk"
-- 2. X axis: "Democracy score"
-- 3. Color by: "Category"
-- 4. Sort on democracy score (descending)
-- 5. Insight: quick overview of the most and least shared desks
--
-- VISUALIZATION 3: TABLE
-- 1. Sort on "Democracy score" (descending)
-- 2. Conditional formatting:
--    - Democracy score >= 80 → Green
--    - Democracy score < 40 → Red
-- 3. Filter on "Category" to focus on specific types
--
-- TIPS:
-- - Add a filter on "Total bookings" to focus on active desks
-- - Combine with location data (floor/area) for space planning
-- - Export to CSV for capacity planning
-- - Change the period (NOW() - INTERVAL '12 weeks') for a different analysis
-- - Compare the democracy score over time to see changes in user behaviour
