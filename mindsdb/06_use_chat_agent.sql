-- Chat with your booking data via the AI agent
-- Run after creating the model in 05_create_chat_agent.sql

-- Example 1: Simple question
SELECT answer
FROM awaio_chat_agent
WHERE question = 'Which weekday has the most bookings?'

-- Example 2: Question with a JOIN to actual data
SELECT
  t.question,
  m.answer
FROM (
  SELECT 'How many bookings are there in total?' AS question
  UNION ALL
  SELECT 'Which desk is the most popular?'
  UNION ALL
  SELECT 'Which days have the least activity?'
) AS t
JOIN awaio_chat_agent AS m

-- Example 3: Question based on actual statistics
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
  'We have ',
  CAST(stats.total_bookings AS VARCHAR),
  ' bookings from ',
  CAST(stats.unique_users AS VARCHAR),
  ' users. What does this say about our utilisation?'
)
