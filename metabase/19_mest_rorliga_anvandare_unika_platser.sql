-- Dashboard 19: Mest rörliga användare - unika platser över tid
-- Identifierar användare som använder många olika entities (aldrig samma plats)
-- Mäter "rörlighet" som antal unika platser per vecka och total variation
-- OBS: Fungerar med både anonymiserade (User ABC123) och icke-anonymiserade användare
--
-- Score-beräkning:
--   Score = (Totalt unika platser) / (Snitt besök/plats)
--   Exempel: 25 unika platser / 2.3 besök per plats = 10.9 score
--   Högre score = mer rörlig (många platser, få återbesök)
--   Lägre score = mer stationär (få platser, många återbesök)
--
-- Visualisering: Scatter Plot (X=Unika platser, Y=Besök/plats, Size=Score)

WITH user_bookings AS (
    -- Alla bokningar med veckonummer
    -- OBS: owner_id är Awaio's user_id (stabil identifierare)
    -- u.name är antingen verkligt namn eller anonymiserat (User ABC123)
    SELECT
        b.owner_id,
        COALESCE(u.name, 'Användare ' || b.owner_id) AS användare,  -- Fallback om användare saknas
        b.entity_id,
        e.name AS plats_namn,
        e.group_tag,
        DATE(b.start_time) AS datum,
        DATE_TRUNC('week', b.start_time) AS vecka
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')
      AND b.start_time >= NOW() - INTERVAL '90 days'
),
weekly_stats AS (
    -- Statistik per användare och vecka
    SELECT
        owner_id,
        användare,
        vecka,
        COUNT(DISTINCT entity_id) AS unika_platser_veckan,
        COUNT(DISTINCT datum) AS bokningsdagar_veckan,
        COUNT(DISTINCT CASE WHEN group_tag = 'desk' THEN entity_id END) AS unika_skrivbord,
        COUNT(DISTINCT CASE WHEN group_tag = 'room' THEN entity_id END) AS unika_rum
    FROM user_bookings
    GROUP BY owner_id, användare, vecka
),
user_stats AS (
    -- Aggregera över alla veckor
    SELECT
        owner_id,
        användare,
        COUNT(DISTINCT vecka) AS antal_veckor,
        SUM(bokningsdagar_veckan) AS totalt_bokningsdagar,
        ROUND(AVG(unika_platser_veckan)::numeric, 1) AS snitt_unika_platser_per_vecka,
        MAX(unika_platser_veckan) AS max_unika_platser_en_vecka,
        ROUND(AVG(unika_skrivbord)::numeric, 1) AS snitt_unika_skrivbord_per_vecka,
        ROUND(AVG(unika_rum)::numeric, 1) AS snitt_unika_rum_per_vecka
    FROM weekly_stats
    GROUP BY owner_id, användare
    HAVING SUM(bokningsdagar_veckan) >= 5  -- Minst 5 bokningsdagar totalt
),
total_diversity AS (
    -- Total variation över hela perioden
    SELECT
        owner_id,
        COUNT(DISTINCT entity_id) AS totalt_unika_platser,
        COUNT(DISTINCT CASE WHEN group_tag = 'desk' THEN entity_id END) AS totalt_unika_skrivbord,
        COUNT(DISTINCT CASE WHEN group_tag = 'room' THEN entity_id END) AS totalt_unika_rum,
        -- Räkna hur ofta samma plats används (lägre = mer variation)
        ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT entity_id), 0), 1) AS genomsnitt_besok_per_plats
    FROM user_bookings
    GROUP BY owner_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY td.totalt_unika_platser DESC, td.genomsnitt_besok_per_plats ASC) AS "#",
    us.användare AS "Användare",
    us.totalt_bokningsdagar AS "Bokningsdagar",
    td.totalt_unika_platser AS "Unika platser",
    td.totalt_unika_skrivbord AS "Unika desk",
    td.totalt_unika_rum AS "Unika rum",
    us.snitt_unika_platser_per_vecka AS "Snitt/vecka",
    us.max_unika_platser_en_vecka AS "Max/vecka",
    td.genomsnitt_besok_per_plats AS "Besök/plats",
    -- "Variation score": fler unika platser och färre återbesök = högre score
    ROUND((td.totalt_unika_platser::numeric / NULLIF(td.genomsnitt_besok_per_plats, 0))::numeric, 1) AS "Score"
FROM user_stats us
JOIN total_diversity td ON us.owner_id = td.owner_id
ORDER BY td.totalt_unika_platser DESC, td.genomsnitt_besok_per_plats ASC
LIMIT 10;
