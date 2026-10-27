# AI Chat Agent for Awaio booking data

## Overview
Create a conversational agent that can answer questions about your bookings.

## Setup

### Option 1: with OpenAI (requires an API key)

```sql
-- 1. Configure the OpenAI ML engine first
CREATE ML_ENGINE openai_engine
FROM openai
USING
  api_key = 'your-openai-api-key';

-- 2. Create the chat agent
CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'openai_engine',
  model_name = 'gpt-4',
  prompt_template = 'You are a helpful assistant that analyses booking data.

  The user asks: {{question}}

  Answer in English and be concrete.';
```

### Option 2: with Hugging Face (free)

```sql
-- Needs no API key, uses an open model
CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'huggingface',
  task = 'text-generation',
  model_name = 'mistralai/Mistral-7B-Instruct-v0.2',
  input_column = 'question';
```

### Option 3: with a local LLM (Ollama)

```sql
-- If you run Ollama locally
CREATE ML_ENGINE ollama_engine
FROM ollama
USING
  host = 'host.docker.internal:11434';

CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'ollama_engine',
  model_name = 'llama2',
  prompt_template = 'Answer in English: {{question}}';
```

## Usage

### Simple question
```sql
SELECT answer
FROM awaio_chat_agent
WHERE question = 'How many bookings do we have this week?'
```

### Several questions
```sql
SELECT
  t.question,
  m.answer
FROM (
  SELECT 'Which weekday has the most bookings?' AS question
  UNION ALL
  SELECT 'Which room is the most popular?'
  UNION ALL
  SELECT 'What is the average booking duration?'
) AS t
JOIN awaio_chat_agent AS m
```

### Question with actual data
```sql
-- Combine actual statistics with an AI answer
SELECT
  m.answer,
  stats.total_bookings,
  stats.unique_users
FROM awaio_chat_agent AS m
JOIN (
  SELECT
    COUNT(*) as total_bookings,
    COUNT(DISTINCT owner_id) as unique_users
  FROM awaio_postgres.bookings
) AS stats
WHERE m.question = 'Analyse our booking pattern based on the statistics'
```

## Advanced use cases

### 1. Automatic report

```sql
-- Generate a weekly report
SELECT m.answer AS weekly_report
FROM awaio_chat_agent AS m
JOIN (
  SELECT
    COUNT(*) as this_week,
    (SELECT COUNT(*)
     FROM awaio_postgres.bookings
     WHERE start_time >= NOW() - INTERVAL '14 days'
       AND start_time < NOW() - INTERVAL '7 days') as last_week
  FROM awaio_postgres.bookings
  WHERE start_time >= NOW() - INTERVAL '7 days'
) AS stats
WHERE m.question = CONCAT(
  'Write a short weekly report. This week: ',
  CAST(stats.this_week AS VARCHAR),
  ' bookings. Last week: ',
  CAST(stats.last_week AS VARCHAR),
  ' bookings.'
)
```

### 2. Recommendations

```sql
-- Get recommendations based on under-use
SELECT m.answer AS recommendations
FROM awaio_chat_agent AS m
JOIN (
  SELECT
    e.name,
    COUNT(b.id) as booking_count
  FROM awaio_postgres.entities e
  LEFT JOIN awaio_postgres.bookings b ON e.id = b.entity_id
  WHERE e.group_tag = 'desk'
  GROUP BY e.name
  HAVING COUNT(b.id) < 5
) AS underused
WHERE m.question = 'Give me recommendations for under-used resources'
```

### 3. Trend analysis

```sql
-- Analyse trends
SELECT m.answer AS trend_analysis
FROM awaio_chat_agent AS m
JOIN (
  SELECT
    DATE_TRUNC('week', start_time) as week,
    COUNT(*) as bookings
  FROM awaio_postgres.bookings
  WHERE start_time >= NOW() - INTERVAL '4 weeks'
  GROUP BY week
  ORDER BY week
) AS trends
WHERE m.question = 'Analyse the booking trend over the last 4 weeks'
```

## Combining with RAG (Retrieval Augmented Generation)

To make the agent smarter you can combine it with a knowledge base:

```sql
-- Create a knowledge base with documentation
CREATE MODEL awaio_knowledge
PREDICT answer
USING
  engine = 'openai_engine',
  mode = 'conversational',
  user_column = 'question',
  assistant_column = 'answer',
  prompt_template = 'Context about Awaio:

  - We have 57 desks spread over 3 floors
  - Plan 1: 15 desks
  - Plan 2: 18 desks
  - Plan 3: 24 desks
  - Tillsammansytan: 8 desks

  Question: {{question}}';
```

## Troubleshooting

### "ML_ENGINE not found"
**Solution:** create the ML_ENGINE for OpenAI/Ollama first

### "API key invalid"
**Solution:** check your OpenAI API key

### Slow answers
**Solution:**
- Use a smaller model (gpt-3.5-turbo instead of gpt-4)
- Or use a local Ollama

### Answers in the wrong language
**Solution:** add "ALWAYS answer in English" (or your language) to the prompt_template

## Best practices

1. **Clear prompts**: specify language and format
2. **Limit the context**: for large amounts of data, aggregate first
3. **Cache results**: save common questions as VIEWs
4. **Security**: do not expose sensitive data in prompts

## Next steps

1. Choose an LLM provider (OpenAI, Hugging Face or Ollama)
2. Create the ML_ENGINE (if needed)
3. Create the chat agent with [05_create_chat_agent.sql](05_create_chat_agent.sql)
4. Test with [06_use_chat_agent.sql](06_use_chat_agent.sql)
5. Integrate it into Metabase or your own app

## Integration with Metabase

You can create "Question Cards" in Metabase that run these queries:

```sql
-- Metabase question: "Weekly summary"
SELECT answer FROM awaio_chat_agent
WHERE question = 'Summarise this week''s bookings'
```

This creates an auto-generated text widget in your dashboard! 📊
