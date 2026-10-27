# Configuring Claude in MindsDB

MindsDB can use Claude as the LLM to analyse and interact with your booking data in natural language.

## Step 1: Get an Anthropic API key

1. Go to https://console.anthropic.com/
2. Create an account or log in
3. Navigate to "API Keys"
4. Create a new API key and copy it

## Step 2: Configure Claude in MindsDB

Open the MindsDB Web UI at http://localhost:47334 and run the following SQL:

```sql
CREATE ML_ENGINE anthropic_engine
FROM anthropic
USING
  api_key = 'your-anthropic-api-key';
```

## Step 3: Create a Claude model

### Example 1: booking analysis with Claude

```sql
CREATE MODEL awaio_chat_model
PREDICT answer
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Analyse the following booking data and answer the question: {{question}}.

  Data: {{context}}';
```

### Example 2: generate insights from booking data

```sql
CREATE MODEL booking_insights
PREDICT insight
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Based on these bookings: {{booking_data}},

  Give insights about:
  1. The most popular times
  2. Usage patterns
  3. Recommendations for optimisation';
```

## Step 4: Use Claude to analyse data

### Ask about booking data
```sql
SELECT answer
FROM awaio_chat_model
WHERE question = 'Which are the most popular desks on Mondays between 09 and 12?'
AND context = (
  SELECT JSON_AGG(
    JSON_BUILD_OBJECT(
      'desk_name', e.name,
      'bookings', COUNT(*)
    )
  )
  FROM bookings b
  JOIN entities e ON b.entity_id = e.id
  WHERE e.group_tag = 'desk'
  AND EXTRACT(DOW FROM b.start_time) = 1
  AND EXTRACT(HOUR FROM b.start_time) BETWEEN 9 AND 12
  GROUP BY e.name
  ORDER BY COUNT(*) DESC
  LIMIT 10
);
```

### Get a summary of the booking data
```sql
SELECT insight
FROM booking_insights
WHERE booking_data = (
  SELECT JSON_AGG(
    JSON_BUILD_OBJECT(
      'date', DATE(start_time),
      'total_bookings', COUNT(*),
      'unique_users', COUNT(DISTINCT owner_id)
    )
  )
  FROM awaio_postgres.bookings
  WHERE start_time >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY DATE(start_time)
);
```

## Advanced use cases

### 1. Chatbot for the booking history

```sql
CREATE MODEL booking_chatbot
PREDICT response
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'You are a helpful assistant for the Awaio booking system.

  Booking data: {{booking_context}}

  User question: {{user_question}}

  Answer in English and give concrete insights based on the data.';
```

Use the chat:
```sql
SELECT response
FROM booking_chatbot
WHERE user_question = 'How many bookings did we have last week compared with this week?'
AND booking_context = (
  SELECT JSON_BUILD_OBJECT(
    'last_week', (
      SELECT COUNT(*) FROM awaio_postgres.bookings
      WHERE start_time >= CURRENT_DATE - INTERVAL '14 days'
      AND start_time < CURRENT_DATE - INTERVAL '7 days'
    ),
    'this_week', (
      SELECT COUNT(*) FROM awaio_postgres.bookings
      WHERE start_time >= CURRENT_DATE - INTERVAL '7 days'
    )
  )
);
```

### 2. Generate recommendations

```sql
CREATE MODEL desk_recommendations
PREDICT recommendation
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Based on the user''s booking history: {{user_history}}

  And the available desks: {{available_desks}}

  Recommend the 3 best desks for the user and explain why.';
```

### 3. Anomaly explanation

```sql
CREATE MODEL anomaly_explainer
PREDICT explanation
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Analyse this booking, which may be unusual: {{booking_details}}

  Compare with the normal patterns: {{normal_patterns}}

  Explain why this booking may be unusual and whether it needs attention.';
```

### 4. Natural language to SQL

```sql
CREATE MODEL nl_to_sql
PREDICT sql_query
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Database schema:
  - bookings (id, entity_id, owner_id, start_time, end_time, status)
  - entities (id, name, group_tag, parent_id)
  - users (id, email, display_name)

  User question: {{natural_language_query}}

  Generate a correct PostgreSQL query that answers the question.';
```

Using NL-to-SQL:
```sql
SELECT sql_query
FROM nl_to_sql
WHERE natural_language_query = 'Show all desk bookings longer than 4 hours';
```

## Combining Claude with ML models

### Explaining ML predictions with Claude

```sql
-- First: create a prediction model
CREATE MODEL booking_predictor
FROM awaio_postgres (
  SELECT
    entity_id,
    EXTRACT(DOW FROM start_time) as day_of_week,
    EXTRACT(HOUR FROM start_time) as hour,
    COUNT(*) as booking_count
  FROM bookings
  GROUP BY entity_id, day_of_week, hour
)
PREDICT booking_count;

-- Then: use Claude to explain the prediction
CREATE MODEL prediction_explainer
PREDICT explanation
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'The ML model predicts: {{prediction}}

  Explain this prediction in simple terms and give recommendations.';
```

## Python example

```python
import mysql.connector
import os

# Connect to MindsDB
connection = mysql.connector.connect(
    host='localhost',
    port=47335,
    user='mindsdb',
    password=''
)

cursor = connection.cursor()

# Configure the Claude engine
cursor.execute(f"""
    CREATE ML_ENGINE IF NOT EXISTS anthropic_engine
    FROM anthropic
    USING
      api_key = '{os.getenv("ANTHROPIC_API_KEY")}';
""")

# Create a chatbot model
cursor.execute("""
    CREATE MODEL IF NOT EXISTS booking_chat
    PREDICT response
    USING
      engine = 'anthropic_engine',
      model_name = 'claude-3-5-sonnet-20241022',
      prompt_template = 'Booking data: {{data}}

      Question: {{question}}

      Answer in English.';
""")

# Ask a question
question = "Which desks are the most popular?"
cursor.execute(f"""
    SELECT response
    FROM booking_chat
    WHERE question = '{question}'
    AND data = (
        SELECT JSON_AGG(
            JSON_BUILD_OBJECT('desk', name, 'count', booking_count)
        )
        FROM (
            SELECT e.name, COUNT(*) as booking_count
            FROM awaio_postgres.bookings b
            JOIN awaio_postgres.entities e ON b.entity_id = e.id
            WHERE e.group_tag = 'desk'
            GROUP BY e.name
            ORDER BY COUNT(*) DESC
            LIMIT 10
        ) t
    );
""")

result = cursor.fetchone()
print(f"Claude answers: {result[0]}")

cursor.close()
connection.close()
```

## Environment variables

Add your Anthropic API key to `.env`:

```bash
# Anthropic API Configuration
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
```

## Tips and best practices

1. **Choose the right Claude model**:
   - `claude-3-5-sonnet-20241022`: best balance between speed and quality
   - `claude-3-opus-20240229`: highest quality, slower
   - `claude-3-haiku-20240307`: fastest, for simpler tasks

2. **Optimise prompts**:
   - Be specific in your instructions
   - Include examples in the prompt_template
   - Limit the data to the relevant fields

3. **Manage costs**:
   - Cache frequently used queries
   - Use Haiku for simple tasks
   - Limit the context size

4. **Security**:
   - Store API keys in environment variables
   - Never use hard-coded keys
   - Restrict access to MindsDB

## Troubleshooting

### Check that the engine has been created
```sql
SHOW ML_ENGINES;
```

### List all models
```sql
SHOW MODELS;
```

### See the model details
```sql
DESCRIBE booking_chat;
```

### Test the connection
```sql
SELECT *
FROM anthropic_engine
WHERE prompt = 'Say hello!';
```

## Resources

- [MindsDB + Anthropic Documentation](https://docs.mindsdb.com/integrations/ai-engines/anthropic)
- [Claude API Documentation](https://docs.anthropic.com/)
- [MindsDB AI Tables](https://docs.mindsdb.com/sql/tutorials/ai-tables)
