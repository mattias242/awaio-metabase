-- Dashboard 9b: Jämförelse bokningar per veckodag - RUM (senaste 4 veckor vs tidigare 4 veckor)
-- Visar antal bokningar per veckodag med två serier för jämförelse
-- Exkluderar rum i "Tillsammansytan"
-- Visualisering: Grouped Bar Chart (Column chart med series)

WITH recent_period AS (
    -- Senaste 4 veckorna
    SELECT
        CASE EXTRACT(DOW FROM b.start_time)
            WHEN 0 THEN '7-Söndag'
            WHEN 1 THEN '1-Måndag'
            WHEN 2 THEN '2-Tisdag'
            WHEN 3 THEN '3-Onsdag'
            WHEN 4 THEN '4-Torsdag'
            WHEN 5 THEN '5-Fredag'
            WHEN 6 THEN '6-Lördag'
        END AS veckodag,
        EXTRACT(DOW FROM b.start_time) AS dow_num,
        COUNT(*) AS antal
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN entities parent ON e.parent_id = parent.id
    WHERE b.start_time >= NOW() - INTERVAL '4 weeks'
      AND b.start_time < NOW()
      AND e.group_tag = 'room'
      AND (parent.name IS NULL OR parent.name != 'Tillsammansytan')
    GROUP BY EXTRACT(DOW FROM b.start_time)
),
previous_period AS (
    -- Föregående 4 veckor (vecka 5-8 tillbaka)
    SELECT
        CASE EXTRACT(DOW FROM b.start_time)
            WHEN 0 THEN '7-Söndag'
            WHEN 1 THEN '1-Måndag'
            WHEN 2 THEN '2-Tisdag'
            WHEN 3 THEN '3-Onsdag'
            WHEN 4 THEN '4-Torsdag'
            WHEN 5 THEN '5-Fredag'
            WHEN 6 THEN '6-Lördag'
        END AS veckodag,
        EXTRACT(DOW FROM b.start_time) AS dow_num,
        COUNT(*) AS antal
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN entities parent ON e.parent_id = parent.id
    WHERE b.start_time >= NOW() - INTERVAL '8 weeks'
      AND b.start_time < NOW() - INTERVAL '4 weeks'
      AND e.group_tag = 'room'
      AND (parent.name IS NULL OR parent.name != 'Tillsammansytan')
    GROUP BY EXTRACT(DOW FROM b.start_time)
)
SELECT
    rp.veckodag AS "Veckodag",
    COALESCE(rp.antal, 0) AS "Senaste 4 veckorna",
    COALESCE(pp.antal, 0) AS "Föregående 4 veckor",
    ROUND(
        (CASE
            WHEN COALESCE(pp.antal, 0) = 0 THEN 0
            ELSE ((COALESCE(rp.antal, 0)::NUMERIC - COALESCE(pp.antal, 0)) / COALESCE(pp.antal, 0) * 100)
        END)::NUMERIC,
        1
    ) AS "Förändring %"
FROM recent_period rp
FULL OUTER JOIN previous_period pp ON rp.dow_num = pp.dow_num
ORDER BY COALESCE(rp.dow_num, pp.dow_num);
