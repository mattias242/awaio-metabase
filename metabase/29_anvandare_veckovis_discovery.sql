-- Query 29: Veckovis Discovery-trend per användare
-- Visar hur många NYA platser användare testar varje vecka över tid
-- Mäter "discovery rate" - andel bokningar som är helt nya platser
-- OBS: Fungerar med både anonymiserade (User ABC123) och icke-anonymiserade användare
--
-- Metrics:
--   - Nya platser: Platser användaren aldrig använt innan (this week)
--   - Discovery rate: % av veckans bokningar som är nya platser
--   - Kumulativa platser: Totalt antal unika platser hittills
--
-- Visualisering: Line chart (vecka på X-axis, flera metrics som lines)
-- Alternativ: Stacked area chart för att visa progression

WITH user_weekly_bookings AS (
    -- Alla bokningar grupperade per användare, vecka och plats
    SELECT
        b.owner_id,
        COALESCE(u.name, 'Användare ' || b.owner_id) AS användare,
        DATE_TRUNC('week', b.start_time) AS vecka,
        b.entity_id,
        e.name AS plats_namn,
        e.group_tag,
        COUNT(*) AS antal_bokningar,
        MIN(b.start_time) AS forsta_bokning_veckan
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '12 weeks'  -- 12 veckor bakåt
    GROUP BY b.owner_id, u.name, DATE_TRUNC('week', b.start_time), b.entity_id, e.name, e.group_tag
),
first_time_usage AS (
    -- Hitta första gången användaren använder varje plats (globalt, inte bara per vecka)
    SELECT
        owner_id,
        entity_id,
        MIN(forsta_bokning_veckan) AS forsta_gangen_nagonsin
    FROM user_weekly_bookings
    GROUP BY owner_id, entity_id
),
weekly_discovery AS (
    -- Klassificera varje plats som "ny" eller "återbesök" per vecka
    SELECT
        uwb.owner_id,
        uwb.användare,
        uwb.vecka,
        uwb.entity_id,
        uwb.plats_namn,
        uwb.group_tag,
        uwb.antal_bokningar,
        CASE
            WHEN ftu.forsta_gangen_nagonsin = uwb.vecka THEN 'ny'
            ELSE 'aterbesok'
        END AS plats_status
    FROM user_weekly_bookings uwb
    JOIN first_time_usage ftu ON uwb.owner_id = ftu.owner_id AND uwb.entity_id = ftu.entity_id
),
weekly_stats AS (
    -- Aggregera per användare och vecka
    SELECT
        owner_id,
        användare,
        vecka,
        COUNT(DISTINCT entity_id) AS totala_platser_veckan,
        COUNT(DISTINCT CASE WHEN plats_status = 'ny' THEN entity_id END) AS nya_platser_veckan,
        COUNT(DISTINCT CASE WHEN plats_status = 'aterbesok' THEN entity_id END) AS aterbesok_veckan,
        SUM(antal_bokningar) AS totala_bokningar_veckan,
        SUM(CASE WHEN plats_status = 'ny' THEN antal_bokningar ELSE 0 END) AS bokningar_nya_platser,
        -- Discovery rate: % av bokningar som är på nya platser
        ROUND(
            (SUM(CASE WHEN plats_status = 'ny' THEN antal_bokningar ELSE 0 END)::numeric /
             NULLIF(SUM(antal_bokningar), 0) * 100)::numeric,
            1
        ) AS discovery_rate_procent
    FROM weekly_discovery
    GROUP BY owner_id, användare, vecka
),
cumulative_stats AS (
    -- Kumulativa unika platser över tid
    SELECT
        owner_id,
        användare,
        vecka,
        nya_platser_veckan,
        totala_platser_veckan,
        aterbesok_veckan,
        totala_bokningar_veckan,
        bokningar_nya_platser,
        discovery_rate_procent,
        -- Kumulativ summa av unika platser
        SUM(nya_platser_veckan) OVER (
            PARTITION BY owner_id
            ORDER BY vecka
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS kumulativa_unika_platser
    FROM weekly_stats
)
-- Visa data för topp 5 mest rörliga användare
SELECT
    TO_CHAR(vecka, 'YYYY-WW') AS "Vecka",
    användare AS "Användare",
    nya_platser_veckan AS "Nya platser",
    aterbesok_veckan AS "Återbesök",
    totala_platser_veckan AS "Totalt platser",
    kumulativa_unika_platser AS "Kumulativa",
    discovery_rate_procent AS "Discovery %",
    totala_bokningar_veckan AS "Bokningar"
FROM cumulative_stats
WHERE owner_id IN (
    -- Välj topp 5 användare med flest nya platser totalt
    SELECT owner_id
    FROM (
        SELECT owner_id, SUM(nya_platser_veckan) AS totalt_nya
        FROM weekly_stats
        GROUP BY owner_id
        ORDER BY SUM(nya_platser_veckan) DESC
        LIMIT 5
    ) top_users
)
ORDER BY användare, vecka;

-- ========================================
-- ANVISNINGAR FÖR METABASE
-- ========================================
--
-- VISUALISERING 1: LINE CHART (Rekommenderad)
-- 1. X-axis: "Vecka"
-- 2. Y-axis: "Nya platser", "Discovery %", "Kumulativa"
-- 3. Group by: "Användare"
-- 4. Visar: Trend över tid för varje användare
-- 5. Insight: Ser om discovery-takten ökar eller minskar
--
-- VISUALISERING 2: STACKED AREA CHART
-- 1. X-axis: "Vecka"
-- 2. Y-axis: "Nya platser"
-- 3. Stack by: "Användare"
-- 4. Visar: Total discovery i organisationen över tid
--
-- TIPS:
-- - Ändra LIMIT 5 för att visa fler/färre användare
-- - Filtrera på specifik användare för detaljvy
-- - Lägg till filter för group_tag ('desk' eller 'room')
-- - Exportera till CSV för trendanalys
