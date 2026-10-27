-- Chatta med din bokningsdata via AI-agenten
-- Kör efter att du skapat modellen i 05_create_chat_agent.sql

-- Exempel 1: Enkel fråga
SELECT answer
FROM awaio_chat_agent
WHERE question = 'Vilken veckodag har flest bokningar?'

-- Exempel 2: Fråga med JOIN till faktisk data
SELECT
  t.question,
  m.answer
FROM (
  SELECT 'Hur många bokningar finns det totalt?' AS question
  UNION ALL
  SELECT 'Vilket skrivbord är mest populärt?'
  UNION ALL
  SELECT 'Vilka dagar har minst aktivitet?'
) AS t
JOIN awaio_chat_agent AS m

-- Exempel 3: Fråga baserad på faktisk statistik
SELECT m.answer
FROM awaio_chat_agent AS m
JOIN (
  SELECT
    COUNT(*) as total_bookings,
    COUNT(DISTINCT owner_id) as unique_users,
    MIN(start_time) as first_booking,
    MAX(start_time) as last_booking
  FROM awaio_postgres.bookings
) AS stats
WHERE m.question = CONCAT(
  'Vi har ',
  CAST(stats.total_bookings AS VARCHAR),
  ' bokningar från ',
  CAST(stats.unique_users AS VARCHAR),
  ' användare. Vad säger detta om vårt utnyttjande?'
)
