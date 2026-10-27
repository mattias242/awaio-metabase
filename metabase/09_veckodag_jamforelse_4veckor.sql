-- Dashboard 9: Jämförelse bokningar per veckodag (senaste 4 veckor vs tidigare 4 veckor)
-- Visar antal bokningar per veckodag med två serier för jämförelse
-- Visualisering: Grouped Bar Chart (Column chart med series)

WITH weekdays AS (
    -- Skapa alla veckodagar
    SELECT
        dow,
        CASE dow
            WHEN 0 THEN '7-Söndag'
            WHEN 1 THEN '1-Måndag'
            WHEN 2 THEN '2-Tisdag'
            WHEN 3 THEN '3-Onsdag'
            WHEN 4 THEN '4-Torsdag'
            WHEN 5 THEN '5-Fredag'
            WHEN 6 THEN '6-Lördag'
        END AS veckodag
    FROM generate_series(0, 6) AS dow
),
recent_period AS (
    -- Senaste 4 veckorna
    SELECT
        CASE EXTRACT(DOW FROM start_time)
            WHEN 0 THEN '7-Söndag'
            WHEN 1 THEN '1-Måndag'
            WHEN 2 THEN '2-Tisdag'
            WHEN 3 THEN '3-Onsdag'
            WHEN 4 THEN '4-Torsdag'
            WHEN 5 THEN '5-Fredag'
            WHEN 6 THEN '6-Lördag'
        END AS veckodag,
        EXTRACT(DOW FROM start_time) AS dow_num,
        COUNT(*) AS antal
    FROM bookings
    WHERE start_time >= NOW() - INTERVAL '4 weeks'
      AND start_time < NOW()
    GROUP BY EXTRACT(DOW FROM start_time)
),
previous_period AS (
    -- Föregående 4 veckor (vecka 5-8 tillbaka)
    SELECT
        CASE EXTRACT(DOW FROM start_time)
            WHEN 0 THEN '7-Söndag'
            WHEN 1 THEN '1-Måndag'
            WHEN 2 THEN '2-Tisdag'
            WHEN 3 THEN '3-Onsdag'
            WHEN 4 THEN '4-Torsdag'
            WHEN 5 THEN '5-Fredag'
            WHEN 6 THEN '6-Lördag'
        END AS veckodag,
        EXTRACT(DOW FROM start_time) AS dow_num,
        COUNT(*) AS antal
    FROM bookings
    WHERE start_time >= NOW() - INTERVAL '8 weeks'
      AND start_time < NOW() - INTERVAL '4 weeks'
    GROUP BY EXTRACT(DOW FROM start_time)
)
SELECT
    wd.veckodag AS "Veckodag",
    COALESCE(rp.antal, 0) AS "Senaste 4 veckorna",
    COALESCE(pp.antal, 0) AS "Föregående 4 veckor",
    ROUND(
        (CASE
            WHEN COALESCE(pp.antal, 0) = 0 THEN 0
            ELSE ((COALESCE(rp.antal, 0)::NUMERIC - COALESCE(pp.antal, 0)) / COALESCE(pp.antal, 0) * 100)
        END)::NUMERIC,
        1
    ) AS "Förändring %"
FROM weekdays wd
LEFT JOIN recent_period rp ON wd.dow = rp.dow_num
LEFT JOIN previous_period pp ON wd.dow = pp.dow_num
ORDER BY wd.dow;
