-- Dashboard 20: Mest rörliga användare - aldrig samma plats två dagar i rad
-- Identifierar användare som sällan återvänder till samma plats på varandra följande dagar
-- Mäter "rörlighet" som förmåga att variera plats dag för dag
-- OBS: Fungerar med både anonymiserade (User ABC123) och icke-anonymiserade användare
--
-- Score-beräkning (Nomad score):
--   Score = (% dagar med byte) / (Längsta följd samma plats)
--   Exempel: 85% byte / 3 längsta följd = 28.3 score
--   Högre score = mer nomadisk (byter ofta, aldrig länge på samma plats)
--   Lägre score = mer stationär (byter sällan, stannar länge på samma plats)
--
-- Visualisering: Horizontal Bar Chart (% byte) eller Combo Chart (bars + line)

WITH daily_bookings AS (
    -- Primär plats per användare och dag (den de använder mest)
    -- OBS: owner_id är Awaio's user_id (stabil identifierare över tid)
    -- u.name är antingen verkligt namn eller anonymiserat (User ABC123)
    SELECT
        b.owner_id,
        COALESCE(u.name, 'Användare ' || b.owner_id) AS användare,  -- Fallback om användare saknas
        DATE(b.start_time) AS datum,
        b.entity_id,
        e.name AS plats_namn,
        e.group_tag,
        -- Räkna timmar för att hitta huvudplats om flera bokningar samma dag
        SUM(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600) AS timmar,
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
    -- Endast huvudplatsen per dag
    SELECT *
    FROM daily_bookings
    WHERE rn = 1
),
consecutive_days AS (
    -- Jämför varje dag med nästa dag
    SELECT
        d1.owner_id,
        d1.användare,
        d1.datum,
        d1.entity_id AS entity_idag,
        d1.plats_namn AS plats_idag,
        d2.datum AS nästa_datum,
        d2.entity_id AS entity_nasta_dag,
        d2.plats_namn AS plats_nasta_dag,
        CASE
            WHEN d2.entity_id IS NULL THEN 'ingen_nasta_dag'
            WHEN d1.entity_id = d2.entity_id THEN 'samma_plats'
            WHEN d1.group_tag != d2.group_tag THEN 'byte_typ'
            ELSE 'byte_plats'
        END AS rorlighet_typ
    FROM main_daily_location d1
    LEFT JOIN main_daily_location d2
        ON d1.owner_id = d2.owner_id
        AND d2.datum = d1.datum + INTERVAL '1 day'
),
user_stats AS (
    -- Aggregera statistik per användare
    SELECT
        owner_id,
        användare,
        COUNT(*) AS totalt_bokningsdagar,
        COUNT(CASE WHEN rorlighet_typ = 'samma_plats' THEN 1 END) AS dagar_samma_plats,
        COUNT(CASE WHEN rorlighet_typ = 'byte_plats' THEN 1 END) AS dagar_byte_plats,
        COUNT(CASE WHEN rorlighet_typ = 'byte_typ' THEN 1 END) AS dagar_byte_typ,
        COUNT(CASE WHEN rorlighet_typ IN ('byte_plats', 'byte_typ') THEN 1 END) AS dagar_byte_totalt,
        -- Procent av dagar med byte
        ROUND(
            (COUNT(CASE WHEN rorlighet_typ IN ('byte_plats', 'byte_typ') THEN 1 END)::numeric /
            NULLIF(COUNT(CASE WHEN rorlighet_typ != 'ingen_nasta_dag' THEN 1 END), 0) * 100)::numeric,
            1
        ) AS procent_byte,
        -- Längsta sekvens utan byte
        MAX(streak) AS langsta_sekvens_samma_plats
    FROM (
        SELECT
            cd.*,
            SUM(CASE WHEN rorlighet_typ = 'samma_plats' THEN 0 ELSE 1 END)
                OVER (PARTITION BY cd.owner_id ORDER BY cd.datum) AS streak_group
        FROM consecutive_days cd
    ) grouped
    LEFT JOIN LATERAL (
        SELECT COUNT(*) AS streak
        FROM consecutive_days cd2
        WHERE cd2.owner_id = grouped.owner_id
          AND cd2.rorlighet_typ = 'samma_plats'
        GROUP BY streak_group
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) streaks ON true
    GROUP BY owner_id, användare
    HAVING COUNT(*) >= 5  -- Minst 5 bokningsdagar
)
SELECT
    ROW_NUMBER() OVER (ORDER BY procent_byte DESC, langsta_sekvens_samma_plats ASC) AS "#",
    användare AS "Användare",
    totalt_bokningsdagar AS "Bokningsdagar",
    dagar_byte_totalt AS "Dagar byte plats",
    dagar_byte_typ AS "Byte desk↔rum",
    dagar_samma_plats AS "Samma plats",
    procent_byte AS "% byte",
    COALESCE(langsta_sekvens_samma_plats, 0) AS "Längsta följd",
    -- "Nomad score": hög procent byte och kort längsta följd = hög score
    ROUND((procent_byte / NULLIF(COALESCE(langsta_sekvens_samma_plats, 1), 0))::numeric, 1) AS "Score"
FROM user_stats
ORDER BY procent_byte DESC, langsta_sekvens_samma_plats ASC
LIMIT 10;
