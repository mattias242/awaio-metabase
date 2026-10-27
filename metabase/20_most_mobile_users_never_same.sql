-- Dashboard 20: Most mobile users - never the same place two days in a row
-- Identifies users who rarely return to the same place on consecutive days
-- Measures "mobility" as the ability to vary place from day to day
-- NOTE: Works with both anonymised (User ABC123) and non-anonymised users
--
-- Score (Nomad score):
--   Score = (% days with a change) / (Longest run at the same place)
--   Example: 85% change / longest run of 3 = 28.3 score
--   Higher score = more nomadic (changes often, never long at the same place)
--   Lower score = more stationary (changes rarely, stays long at the same place)
--
-- Visualization: Horizontal Bar Chart (% change) or Combo Chart (bars + line)

WITH daily_bookings AS (
    -- Main place per user and day (the one used the most)
    -- NOTE: owner_id is the Awaio user_id (stable identifier over time)
    -- u.name is either the real name or anonymised (User ABC123)
    SELECT
        b.owner_id,
        COALESCE(u.name, 'User ' || b.owner_id) AS user_name,  -- Fallback if the user is missing
        DATE(b.start_time) AS booking_date,
        b.entity_id,
        e.name AS place_name,
        e.group_tag,
        -- Sum hours to find the main place when there are several bookings on the same day
        SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600) AS hours,
        ROW_NUMBER() OVER (
            PARTITION BY b.owner_id, DATE(b.start_time)
            ORDER BY SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time))) DESC
        ) AS rn
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '90 days'
    GROUP BY b.owner_id, u.name, DATE(b.start_time), b.entity_id, e.name, e.group_tag
),
main_daily_location AS (
    -- Main place per day only
    SELECT *
    FROM daily_bookings
    WHERE rn = 1
),
consecutive_days AS (
    -- Compare each day with the next day
    SELECT
        d1.owner_id,
        d1.user_name,
        d1.booking_date,
        d1.entity_id AS entity_today,
        d1.place_name AS place_today,
        d2.booking_date AS next_date,
        d2.entity_id AS entity_next_day,
        d2.place_name AS place_next_day,
        CASE
            WHEN d2.entity_id IS NULL THEN 'no_next_day'
            WHEN d1.entity_id = d2.entity_id THEN 'same_place'
            WHEN d1.group_tag != d2.group_tag THEN 'changed_type'
            ELSE 'changed_place'
        END AS mobility_type
    FROM main_daily_location d1
    LEFT JOIN main_daily_location d2
        ON d1.owner_id = d2.owner_id
        AND d2.booking_date = d1.booking_date + INTERVAL '1 day'
),
user_stats AS (
    -- Aggregate statistics per user
    SELECT
        owner_id,
        user_name,
        COUNT(*) AS total_booking_days,
        COUNT(CASE WHEN mobility_type = 'same_place' THEN 1 END) AS days_same_place,
        COUNT(CASE WHEN mobility_type = 'changed_place' THEN 1 END) AS days_changed_place,
        COUNT(CASE WHEN mobility_type = 'changed_type' THEN 1 END) AS days_changed_type,
        COUNT(CASE WHEN mobility_type IN ('changed_place', 'changed_type') THEN 1 END) AS days_changed_total,
        -- Percentage of days with a change
        ROUND(
            (COUNT(CASE WHEN mobility_type IN ('changed_place', 'changed_type') THEN 1 END)::numeric /
            NULLIF(COUNT(CASE WHEN mobility_type != 'no_next_day' THEN 1 END), 0) * 100)::numeric,
            1
        ) AS pct_changed,
        -- Longest run without a change
        MAX(streak) AS longest_run_same_place
    FROM (
        SELECT
            cd.*,
            SUM(CASE WHEN mobility_type = 'same_place' THEN 0 ELSE 1 END)
                OVER (PARTITION BY cd.owner_id ORDER BY cd.booking_date) AS streak_group
        FROM consecutive_days cd
    ) grouped
    LEFT JOIN LATERAL (
        SELECT COUNT(*) AS streak
        FROM consecutive_days cd2
        WHERE cd2.owner_id = grouped.owner_id
          AND cd2.mobility_type = 'same_place'
        GROUP BY streak_group
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) streaks ON true
    GROUP BY owner_id, user_name
    HAVING COUNT(*) >= 5  -- At least 5 booking days
)
SELECT
    ROW_NUMBER() OVER (ORDER BY pct_changed DESC, longest_run_same_place ASC) AS "#",
    user_name AS "User",
    total_booking_days AS "Booking days",
    days_changed_total AS "Days changed place",
    days_changed_type AS "Changed desk↔room",
    days_same_place AS "Same place",
    pct_changed AS "% changed",
    COALESCE(longest_run_same_place, 0) AS "Longest run",
    -- "Nomad score": high % changed and short longest run = high score
    ROUND((pct_changed / NULLIF(COALESCE(longest_run_same_place, 1), 0))::numeric, 1) AS "Score"
FROM user_stats
ORDER BY pct_changed DESC, longest_run_same_place ASC
LIMIT 10;
