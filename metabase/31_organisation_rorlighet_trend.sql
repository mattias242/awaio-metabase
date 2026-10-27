-- Query 31: Organisations-rörlighet över tid
-- Visar hur organisationen som helhet rör sig mellan olika platser vecka för vecka
-- Mäter "rörlighets-kultur" - om användare vågar variera sina arbetsplatser
--
-- Metrics:
--   - Aktiva användare: Antal användare som bokat någonting denna vecka
--   - Snitt platser/användare: Genomsnittligt antal unika platser per användare
--   - Rörliga användare %: Andel användare som använt 2+ platser
--   - Totala unika platser: Antal olika platser som används i organisationen
--   - Plats-diversitet: Totala platser / Aktiva användare (högre = mer spridning)
--
-- Visualisering: Line chart med flera metrics över tid
-- Alternativ: Dual-axis chart (volym på vänster, % på höger)

WITH weekly_user_mobility AS (
    -- Beräkna rörlighet per användare och vecka
    SELECT
        DATE_TRUNC('week', b.start_time) AS vecka,
        b.owner_id,
        COALESCE(u.name, 'Användare ' || b.owner_id) AS användare,
        COUNT(DISTINCT b.entity_id) AS unika_platser_anvandare,
        COUNT(*) AS bokningar_anvandare,
        -- Klassificera användare som rörlig (2+ platser) eller stationär (1 plats)
        CASE
            WHEN COUNT(DISTINCT b.entity_id) >= 2 THEN 'rorlig'
            ELSE 'stationar'
        END AS mobilitetsklass
    FROM bookings b
    LEFT JOIN users u ON b.owner_id = u.id
    JOIN entities e ON b.entity_id = e.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '12 weeks'
    GROUP BY DATE_TRUNC('week', b.start_time), b.owner_id, u.name
),
weekly_org_stats AS (
    -- Aggregera på organisationsnivå per vecka
    SELECT
        vecka,
        COUNT(DISTINCT owner_id) AS aktiva_anvandare,
        COUNT(DISTINCT CASE WHEN mobilitetsklass = 'rorlig' THEN owner_id END) AS rorliga_anvandare,
        ROUND(AVG(unika_platser_anvandare)::numeric, 1) AS snitt_platser_per_anvandare,
        SUM(bokningar_anvandare) AS totala_bokningar,
        -- Beräkna totala unika platser för hela organisationen
        (
            SELECT COUNT(DISTINCT entity_id)
            FROM bookings b2
            JOIN entities e2 ON b2.entity_id = e2.id
            WHERE b2.status = 'reserved'
              AND e2.group_tag IN ('desk', 'room')
              AND DATE_TRUNC('week', b2.start_time) = wum.vecka
        ) AS totala_unika_platser,
        -- Procent rörliga användare
        ROUND(
            (COUNT(DISTINCT CASE WHEN mobilitetsklass = 'rorlig' THEN owner_id END)::numeric /
             NULLIF(COUNT(DISTINCT owner_id), 0) * 100)::numeric,
            1
        ) AS rorliga_procent
    FROM weekly_user_mobility wum
    GROUP BY vecka
),
weekly_diversity AS (
    -- Beräkna plats-diversitet (spridning i organisationen)
    SELECT
        vecka,
        aktiva_anvandare,
        rorliga_anvandare,
        rorliga_procent,
        snitt_platser_per_anvandare,
        totala_unika_platser,
        totala_bokningar,
        -- Diversitets-index: hur många platser per aktiv användare
        ROUND(
            (totala_unika_platser::numeric / NULLIF(aktiva_anvandare, 0))::numeric,
            2
        ) AS plats_diversitet,
        -- Glidande medelvärde för att se trender (3-veckors genomsnitt)
        ROUND(
            AVG(snitt_platser_per_anvandare) OVER (
                ORDER BY vecka
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )::numeric,
            1
        ) AS snitt_platser_trend_3v,
        ROUND(
            AVG(rorliga_procent) OVER (
                ORDER BY vecka
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )::numeric,
            1
        ) AS rorliga_procent_trend_3v
    FROM weekly_org_stats
)
-- Huvudquery: Visa organisations-rörlighet över tid
SELECT
    TO_CHAR(vecka, 'YYYY-WW') AS "Vecka",
    aktiva_anvandare AS "Aktiva användare",
    rorliga_anvandare AS "Rörliga användare",
    rorliga_procent AS "Rörliga %",
    snitt_platser_per_anvandare AS "Snitt platser/användare",
    totala_unika_platser AS "Totala platser",
    plats_diversitet AS "Plats-diversitet",
    totala_bokningar AS "Bokningar",
    snitt_platser_trend_3v AS "Trend platser (3v)",
    rorliga_procent_trend_3v AS "Trend rörliga % (3v)"
FROM weekly_diversity
ORDER BY vecka;

-- ========================================
-- ANVISNINGAR FÖR METABASE
-- ========================================
--
-- VISUALISERING 1: LINE CHART (Rekommenderad)
-- 1. X-axis: "Vecka"
-- 2. Y-axis (vänster): "Snitt platser/användare", "Trend platser (3v)"
-- 3. Y-axis (höger): "Rörliga %", "Trend rörliga % (3v)"
-- 4. Visar: Trender i organisationens rörlighet över tid
-- 5. Insight: Ser om rörligheten ökar eller minskar
--
-- VISUALISERING 2: DUAL-AXIS CHART
-- 1. X-axis: "Vecka"
-- 2. Y-axis (vänster): "Aktiva användare", "Rörliga användare"
-- 3. Y-axis (höger): "Rörliga %"
-- 4. Visar: Volym och andel rörliga användare
--
-- VISUALISERING 3: STACKED AREA CHART
-- 1. X-axis: "Vecka"
-- 2. Y-axis: "Rörliga användare" och "Stationära användare" (aktiva - rörliga)
-- 3. Stack: Visa andelen
-- 4. Insight: Visuell fördelning över tid
--
-- VISUALISERING 4: TABLE
-- 1. Sortera på "Vecka" (descending) för att se senaste först
-- 2. Conditional formatting:
--    - "Rörliga %" >= 60 → Grön
--    - "Rörliga %" < 40 → Röd
-- 3. Fokusera på trendkolumner för att se riktning
--
-- TIPS:
-- - Plats-diversitet >1.5 indikerar god spridning i organisationen
-- - Jämför "Snitt platser/användare" med "Trend platser (3v)" för att se om det ökar
-- - Kombinera med Query 29 (per användare) för att identifiera specifika användare
-- - Exportera till CSV för långsiktig trendanalys
-- - Ändra tidsperiod (NOW() - INTERVAL '12 weeks') för längre/kortare analys
-- - Filtrera på specifika group_tags ('desk' vs 'room') för detaljerad analys
--
-- DEFINITION AV METRICS:
-- - Rörlig användare: Använder 2+ olika platser per vecka
-- - Stationär användare: Använder endast 1 plats per vecka
-- - Plats-diversitet: Totala unika platser / Aktiva användare (mått på organisationens spridning)
-- - Trend (3v): Glidande medelvärde över 3 veckor för att filtrera brus
