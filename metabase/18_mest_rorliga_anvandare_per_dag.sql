-- Dashboard 18: Mest rörliga användare - variation per dag
-- Identifierar användare som bokar både skrivbord OCH rum samma dag
-- Mäter "rörlighet" som användning av flera olika platstyper per dag
-- OBS: Fungerar med både anonymiserade (User ABC123) och icke-anonymiserade användare
--
-- Score-beräkning:
--   Score = (Dagar med både desk+rum) + (Snitt platser/dag)
--   Exempel: 15 dagar med båda + 2.5 snitt platser/dag = 17.5 score
--   Högre score = mer rörlig (fler typer och fler platser per dag)
--
-- Visualisering: Table eller Horizontal Bar Chart (använd # som X-axis)

WITH daily_bookings AS (
    -- Gruppera bokningar per användare och dag
    -- OBS: owner_id är Awaio's user_id (stabil över tid)
    -- u.name är antingen verkligt namn eller anonymiserat (User ABC123)
    SELECT
        b.owner_id,
        COALESCE(u.name, 'Användare ' || b.owner_id) AS användare,  -- Fallback om användare saknas
        DATE(b.start_time) AS datum,
        e.group_tag,
        COUNT(DISTINCT b.entity_id) AS antal_olika_platser,
        STRING_AGG(DISTINCT e.name, ', ' ORDER BY e.name) AS plats_lista
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE b.status = 'reserved'
      AND e.group_tag IN ('desk', 'room')  -- Endast skrivbord och rum
      AND b.start_time >= NOW() - INTERVAL '90 days'  -- Senaste 90 dagarna
    GROUP BY b.owner_id, u.name, DATE(b.start_time), e.group_tag
),
daily_diversity AS (
    -- Räkna dagar där användaren har både skrivbord OCH rum
    SELECT
        owner_id,
        användare,
        datum,
        COUNT(DISTINCT group_tag) AS antal_typer,  -- 1=bara desk/room, 2=båda
        SUM(CASE WHEN group_tag = 'desk' THEN antal_olika_platser ELSE 0 END) AS skrivbord_per_dag,
        SUM(CASE WHEN group_tag = 'room' THEN antal_olika_platser ELSE 0 END) AS rum_per_dag,
        SUM(antal_olika_platser) AS totalt_platser_per_dag
    FROM daily_bookings
    GROUP BY owner_id, användare, datum
),
user_stats AS (
    -- Aggregera statistik per användare
    SELECT
        owner_id,
        användare,
        COUNT(DISTINCT datum) AS antal_bokningsdagar,
        COUNT(DISTINCT CASE WHEN antal_typer = 2 THEN datum END) AS dagar_med_bade_desk_och_rum,
        ROUND(AVG(skrivbord_per_dag)::numeric, 1) AS snitt_skrivbord_per_dag,
        ROUND(AVG(rum_per_dag)::numeric, 1) AS snitt_rum_per_dag,
        ROUND(AVG(totalt_platser_per_dag)::numeric, 1) AS snitt_platser_per_dag,
        MAX(totalt_platser_per_dag) AS max_platser_en_dag,
        -- "Rörlighets-score": dagar med båda typerna + snitt platser per dag
        COUNT(DISTINCT CASE WHEN antal_typer = 2 THEN datum END) +
        ROUND(AVG(totalt_platser_per_dag)::numeric, 1) AS rorlighets_score
    FROM daily_diversity
    GROUP BY owner_id, användare
    HAVING COUNT(DISTINCT datum) >= 5  -- Minst 5 bokningsdagar för att vara relevant
)
SELECT
    ROW_NUMBER() OVER (ORDER BY dagar_med_bade_desk_och_rum DESC, snitt_platser_per_dag DESC) AS "#",
    användare AS "Användare",
    antal_bokningsdagar AS "Bokningsdagar",
    dagar_med_bade_desk_och_rum AS "Desk+Rum dagar",
    snitt_skrivbord_per_dag AS "Snitt desk/dag",
    snitt_rum_per_dag AS "Snitt rum/dag",
    snitt_platser_per_dag AS "Snitt platser/dag",
    max_platser_en_dag AS "Max platser",
    ROUND(rorlighets_score::numeric, 1) AS "Score"
FROM user_stats
ORDER BY dagar_med_bade_desk_och_rum DESC, snitt_platser_per_dag DESC
LIMIT 10;
