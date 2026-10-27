-- Dashboard 17: Detaljerad vy av konsekutiva bokningar per rum
-- Visar specifika bokningsserier med datum, användare och tider
-- Hjälper till att identifiera mönster i hur rum används över flera dagar
-- Visualisering: Table (kan filtreras på rum_namn)

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
consecutive_series AS (
    -- Identifiera serier av på varandra följande bokningar
    SELECT
        lb1.entity_id,
        lb1.rum_namn,
        lb1.område,
        lb1.owner_id,
        lb1.användare,
        MIN(lb1.booking_date) AS serie_start_datum,
        MAX(lb2.booking_date) AS serie_slut_datum,
        COUNT(DISTINCT lb2.booking_date) AS antal_dagar,
        MIN(lb2.start_time) AS första_bokning,
        MAX(lb2.end_time) AS sista_bokning,
        ROUND(AVG(lb2.timmar)::numeric, 1) AS snitt_timmar_per_dag,
        ROUND(SUM(lb2.timmar)::numeric, 1) AS totalt_timmar,
        STRING_AGG(
            TO_CHAR(lb2.booking_date, 'YYYY-MM-DD') || ' (' || ROUND(lb2.timmar::numeric, 1) || 'h)',
            ', '
            ORDER BY lb2.booking_date
        ) AS datum_lista
    FROM long_bookings lb1
    JOIN long_bookings lb2
        ON lb1.entity_id = lb2.entity_id
        AND lb1.owner_id = lb2.owner_id
        AND lb2.booking_date BETWEEN lb1.booking_date AND lb1.booking_date + INTERVAL '6 days'
    GROUP BY lb1.entity_id, lb1.rum_namn, lb1.område, lb1.owner_id, lb1.användare, lb1.booking_date
    HAVING COUNT(DISTINCT lb2.booking_date) >= 2
)
SELECT
    rum_namn AS "Rum",
    område AS "Område",
    användare AS "Användare",
    antal_dagar AS "Dagar i rad",
    TO_CHAR(serie_start_datum, 'YYYY-MM-DD') AS "Startdatum",
    TO_CHAR(serie_slut_datum, 'YYYY-MM-DD') AS "Slutdatum",
    TO_CHAR(första_bokning, 'HH24:MI') AS "Start tid",
    TO_CHAR(sista_bokning, 'HH24:MI') AS "Slut tid",
    snitt_timmar_per_dag AS "Snitt h/dag",
    totalt_timmar AS "Totalt timmar",
    datum_lista AS "Detaljerade datum (timmar)"
FROM consecutive_series
ORDER BY antal_dagar DESC, totalt_timmar DESC, serie_start_datum DESC
LIMIT 50;
