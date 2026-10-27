-- Query 30: Skrivbords-demokrati (Desk Sharing & Diversity)
-- Visar vilka skrivbord som delas av många användare vs domineras av en enskild användare
-- Mäter "demokrati-grad" - hur jämnt fördelat användandet är
--
-- Metrics:
--   - Totala användare: Antal unika användare som använt skrivbordet
--   - Dominans-ratio: Top användares andel av totala bokningar (%)
--   - Demokrati-score: 100 - dominans_ratio (högre = mer jämnt delat)
--   - Top användare: Användaren med flest bokningar
--
-- Visualisering: Scatter plot (X=Totala användare, Y=Demokrati-score, Size=Totala bokningar)
-- Alternativ: Horizontal bar chart sorterad på demokrati-score

WITH desk_bookings AS (
    -- Alla bokningar för skrivbord senaste 12 veckorna
    SELECT
        b.entity_id,
        e.name AS skrivbord,
        b.owner_id,
        COALESCE(u.name, 'Användare ' || b.owner_id) AS användare,
        COUNT(*) AS antal_bokningar
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag = 'desk'
      AND b.start_time >= NOW() - INTERVAL '12 weeks'
    GROUP BY b.entity_id, e.name, b.owner_id, u.name
),
desk_stats AS (
    -- Aggregera statistik per skrivbord
    SELECT
        entity_id,
        skrivbord,
        COUNT(DISTINCT owner_id) AS totala_anvandare,
        SUM(antal_bokningar) AS totala_bokningar,
        -- Hitta top användare och deras andel
        MAX(antal_bokningar) AS max_bokningar_en_anvandare,
        ROUND(
            (MAX(antal_bokningar)::numeric / NULLIF(SUM(antal_bokningar), 0) * 100)::numeric,
            1
        ) AS dominans_ratio,
        -- Demokrati-score: 100 = perfekt jämnt fördelat, 0 = en användare dominerar helt
        ROUND(
            (100 - (MAX(antal_bokningar)::numeric / NULLIF(SUM(antal_bokningar), 0) * 100))::numeric,
            1
        ) AS demokrati_score
    FROM desk_bookings
    GROUP BY entity_id, skrivbord
),
top_users AS (
    -- Hitta namn på top användare per skrivbord
    SELECT DISTINCT ON (entity_id)
        entity_id,
        användare AS top_anvandare,
        antal_bokningar AS top_anvandare_bokningar
    FROM desk_bookings
    ORDER BY entity_id, antal_bokningar DESC
)
-- Huvudquery: Visa alla skrivbord med demokrati-metrics
SELECT
    ds.skrivbord AS "Skrivbord",
    ds.totala_anvandare AS "Totalt användare",
    tu.top_anvandare AS "Top användare",
    tu.top_anvandare_bokningar AS "Top bokningar",
    ds.dominans_ratio AS "Dominans %",
    ds.demokrati_score AS "Demokrati-score",
    ds.totala_bokningar AS "Totalt bokningar",
    -- Kategori för klassificering
    CASE
        WHEN ds.demokrati_score >= 80 THEN 'Högt delad'
        WHEN ds.demokrati_score >= 60 THEN 'Delad'
        WHEN ds.demokrati_score >= 40 THEN 'Måttligt delad'
        WHEN ds.demokrati_score >= 20 THEN 'Lågt delad'
        ELSE 'Privat/Dominerad'
    END AS "Kategori"
FROM desk_stats ds
JOIN top_users tu ON ds.entity_id = tu.entity_id
WHERE ds.totala_bokningar >= 5  -- Filtrera skrivbord med minst 5 bokningar
ORDER BY ds.demokrati_score DESC, ds.totala_anvandare DESC;

-- ========================================
-- ANVISNINGAR FÖR METABASE
-- ========================================
--
-- VISUALISERING 1: SCATTER PLOT (Rekommenderad)
-- 1. X-axis: "Totalt användare"
-- 2. Y-axis: "Demokrati-score"
-- 3. Size/Bubble: "Totalt bokningar"
-- 4. Color: "Kategori"
-- 5. Insight: Skrivbord i övre högra hörnet är mest demokratiska och mest använda
--
-- VISUALISERING 2: HORIZONTAL BAR CHART
-- 1. Y-axis: "Skrivbord"
-- 2. X-axis: "Demokrati-score"
-- 3. Color by: "Kategori"
-- 4. Sortera på demokrati-score (descending)
-- 5. Insight: Snabb översikt av mest/minst delade skrivbord
--
-- VISUALISERING 3: TABLE
-- 1. Sortera på "Demokrati-score" (descending)
-- 2. Conditional formatting:
--    - Demokrati-score >= 80 → Grön
--    - Demokrati-score < 40 → Röd
-- 3. Filter på "Kategori" för att fokusera på specifika typer
--
-- TIPS:
-- - Lägg till filter för "Totalt bokningar" för att fokusera på aktiva skrivbord
-- - Kombinera med geografisk data (plan/yta) för lokalplanering
-- - Exportera till CSV för capacity planning
-- - Ändra tidsperiod (NOW() - INTERVAL '12 weeks') för annan analys
-- - Jämför demokrati-score över tid för att se förändringar i användarbeteende
