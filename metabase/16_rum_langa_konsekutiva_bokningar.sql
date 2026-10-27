-- Dashboard 16: Rum med långa bokningar (>4h) och flera dagar i rad
-- Identifierar rum som ofta bokas för lång tid och över flera på varandra följande dagar
-- Detta kan indikera rum som används för längre möten, workshops, eller permanent allokering
-- Visualisering: Table

WITH long_bookings AS (
    -- Alla bokningar längre än 4 timmar för rum
    SELECT
        b.id AS booking_id,
        b.entity_id,
        e.name AS rum_namn,
        parent.name AS område,
        b.owner_id,
        DATE(b.start_time) AS booking_date,
        b.start_time,
        b.end_time,
        EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 AS timmar,
        u.name AS användare
    FROM bookings b
    JOIN entities e ON b.entity_id = e.id
    LEFT JOIN entities parent ON e.parent_id = parent.id
    LEFT JOIN users u ON b.owner_id = u.id
    WHERE e.group_tag = 'room'
      AND EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600 > 4
      AND b.status = 'reserved'
),
consecutive_bookings AS (
    -- Hitta på varandra följande dagar för samma rum och användare
    SELECT
        lb1.entity_id,
        lb1.rum_namn,
        lb1.område,
        lb1.owner_id,
        lb1.användare,
        lb1.booking_date AS start_date,
        COUNT(DISTINCT lb2.booking_date) AS consecutive_days,
        MIN(lb2.start_time) AS first_booking_start,
        MAX(lb2.end_time) AS last_booking_end,
        ROUND(AVG(lb2.timmar)::numeric, 1) AS snitt_timmar_per_dag,
        ROUND(SUM(lb2.timmar)::numeric, 1) AS totalt_timmar
    FROM long_bookings lb1
    JOIN long_bookings lb2
        ON lb1.entity_id = lb2.entity_id
        AND lb1.owner_id = lb2.owner_id
        AND lb2.booking_date BETWEEN lb1.booking_date AND lb1.booking_date + INTERVAL '6 days'
    GROUP BY lb1.entity_id, lb1.rum_namn, lb1.område, lb1.owner_id, lb1.användare, lb1.booking_date
    HAVING COUNT(DISTINCT lb2.booking_date) >= 2  -- Minst 2 dagar i rad
),
room_stats AS (
    -- Aggregera statistik per rum
    SELECT
        entity_id,
        rum_namn,
        område,
        COUNT(DISTINCT owner_id) AS antal_användare,
        COUNT(*) AS antal_konsekutiva_serier,
        ROUND(AVG(consecutive_days)::numeric, 1) AS snitt_dagar_i_rad,
        MAX(consecutive_days) AS max_dagar_i_rad,
        ROUND(AVG(snitt_timmar_per_dag)::numeric, 1) AS snitt_timmar_per_dag,
        ROUND(SUM(totalt_timmar)::numeric, 1) AS totalt_timmar_alla_serier
    FROM consecutive_bookings
    GROUP BY entity_id, rum_namn, område
)
SELECT
    rum_namn AS "Rum",
    område AS "Område",
    antal_konsekutiva_serier AS "Antal bokningsserier",
    antal_användare AS "Antal användare",
    snitt_dagar_i_rad AS "Snitt dagar i rad",
    max_dagar_i_rad AS "Max dagar i rad",
    snitt_timmar_per_dag AS "Snitt timmar/dag",
    totalt_timmar_alla_serier AS "Totalt timmar"
FROM room_stats
ORDER BY antal_konsekutiva_serier DESC, max_dagar_i_rad DESC, snitt_timmar_per_dag DESC
LIMIT 20;
