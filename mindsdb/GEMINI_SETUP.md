# Google Gemini AI Agent Setup for Awaio

## Step 1: Get a Gemini API key

1. Go to: **https://aistudio.google.com/app/apikey**
2. Log in with your Google account
3. Click "Create API Key"
4. Copy your API key (starts with `AIza...`)

## Step 2: Create the ML engine in MindsDB

Open the MindsDB Web UI (http://localhost:47334) and run:

```sql
CREATE ML_ENGINE gemini_engine
FROM google_gemini
USING
  google_gemini_api_key = 'AIza...YOUR-API-KEY-HERE';
```

**Expected result:** "Query successfully completed"

## Step 3: Create the chat agent

Run [05a_create_gemini_agent.sql](05a_create_gemini_agent.sql) or this SQL:

```sql
CREATE MODEL awaio_gemini_agent
PREDICT answer
USING
  engine = 'gemini_engine',
  model_name = 'gemini-2.5-flash',
  prompt_template = 'You are a helpful assistant that analyses booking data.

  The user asks: {{question}}

  ALWAYS answer in English and be concrete.';
```

**NOTE:** this takes 10-30 seconds the first time.

## Step 4: Test the agent

### Simple question
```sql
SELECT answer
FROM awaio_gemini_agent
WHERE question = 'Which weekday has the most bookings?'
```

### Several questions at once
```sql
SELECT
  t.question,
  m.answer
FROM (
  SELECT 'How many bookings do we have in total?' AS question
  UNION ALL
  SELECT 'Which desk is the most popular?'
  UNION ALL
  SELECT 'Which days have the least activity?'
) AS t
JOIN awaio_gemini_agent AS m
```

### Question with actual statistics
```sql
SELECT
  'Total: ' || stats.total_bookings || ' bookings' AS statistics,
  m.answer AS ai_analysis
FROM awaio_gemini_agent AS m
JOIN (
  SELECT
    COUNT(*) as total_bookings,
    COUNT(DISTINCT owner_id) as unique_users,
    COUNT(DISTINCT entity_id) as unique_resources
  FROM awaio_postgres.bookings
) AS stats
WHERE m.question = CONCAT(
  'We have a total of ',
  CAST(stats.total_bookings AS VARCHAR),
  ' bookings from ',
  CAST(stats.unique_users AS VARCHAR),
  ' unique users across ',
  CAST(stats.unique_resources AS VARCHAR),
  ' different resources. Analyse this and give recommendations.'
)
```

## Step 5: Advanced use cases

### A. Weekly report
```sql
SELECT m.answer AS weekly_report
FROM awaio_gemini_agent AS m
WHERE m.question = 'Write a short summary of this week''s bookings and trends'
```

### B. Under-used resources
```sql
SELECT
  e.name AS resource,
  COUNT(b.id) AS bookings,
  m.answer AS recommendation
FROM awaio_postgres.entities e
LEFT JOIN awaio_postgres.bookings b ON e.id = b.entity_id
JOIN awaio_gemini_agent m
WHERE e.group_tag = 'desk'
  AND m.question = CONCAT(
    'The resource "', e.name, '" has only ',
    CAST(COUNT(b.id) AS VARCHAR),
    ' bookings. Give recommendations for how we can increase its use.'
  )
GROUP BY e.name
HAVING COUNT(b.id) < 10
```

### C. Trend analysis
```sql
SELECT m.answer AS trend_analysis
FROM awaio_gemini_agent m
JOIN (
  SELECT
    EXTRACT(DOW FROM start_time) as weekday,
    COUNT(*) as bookings
  FROM awaio_postgres.bookings
  WHERE start_time >= NOW() - INTERVAL '30 days'
  GROUP BY weekday
  ORDER BY weekday
) trends
WHERE m.question = 'Analyse the booking patterns per weekday and identify trends'
```

## Integration with Metabase

Create "Native Query" widgets in Metabase:

### Widget 1: AI insights
```sql
SELECT answer AS "AI Analysis"
FROM awaio_gemini_agent
WHERE question = 'Summarise the most important insights from the booking data'
```

### Widget 2: Recommendations
```sql
SELECT answer AS "Recommendations"
FROM awaio_gemini_agent
WHERE question = 'Give 3 concrete recommendations for improving resource utilisation'
```

## Gemini-specific benefits

✅ **Free tier** - 60 requests/minute
✅ **Multimodal** - can handle text, images and more
✅ **Fast** - often faster than GPT-4
✅ **Long context** - up to 1M tokens (Gemini 1.5 Pro)
✅ **Multilingual** - good support for many languages, including Swedish

## Choosing a model

MindsDB supports several Gemini models (2025):

```sql
-- Gemini 2.5 Flash (recommended - fast and modern)
model_name = 'gemini-2.5-flash'

-- Gemini 2.5 Pro (longer context and more advanced)
model_name = 'gemini-2.5-pro'

-- Gemini 2.0 Flash (older version)
model_name = 'gemini-2.0-flash'
```

**NOTE:** older models such as `gemini-pro` and `gemini-1.5-pro` have been deprecated since 2025.

## Troubleshooting

### "ML_ENGINE not found"
**Problem:** the Gemini engine has not been created
**Solution:** run CREATE ML_ENGINE first

### "Invalid API key"
**Problem:** wrong API key or not activated
**Solution:**
1. Check the key at https://aistudio.google.com/app/apikey
2. Make sure the Gemini API is enabled for your project

### "Rate limit exceeded"
**Problem:** too many requests
**Solution:** wait 1 minute or upgrade to a paid plan

### Answers in the wrong language
**Problem:** Gemini answers in another language despite the prompt
**Solution:** add "Answer ONLY in English" at the start of the prompt_template

### Slow answers
**Problem:** it takes a long time to get an answer
**Solution:**
- Use shorter prompts
- Limit the amount of data in the JOIN
- Consider caching common questions

## Costs

Gemini has a generous **free tier**:

- **Gemini Pro**: 60 requests/minute free
- **Gemini 1.5 Pro**: 2 requests/minute free
- **Gemini 1.5 Flash**: 15 requests/minute free

For production, see: https://ai.google.dev/pricing

## Security

⚠️ **Important:**
- NEVER expose API keys in version control
- Use environment variables for API keys
- Restrict the API key to specific IP addresses if possible
- Never log sensitive user data in prompts

## Next steps

1. ✅ Get a Gemini API key
2. ✅ Create the ML_ENGINE in MindsDB
3. ✅ Create the awaio_gemini_agent model
4. ✅ Test with simple questions
5. ✅ Integrate into Metabase dashboards
6. ✅ Build a custom chat interface (optional)

**Good luck with your AI agent! 🚀**
