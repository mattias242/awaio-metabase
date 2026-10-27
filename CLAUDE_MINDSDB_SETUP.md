# Konfigurera Claude i MindsDB

MindsDB kan använda Claude som LLM för att analysera och interagera med din bokningsdata på naturligt språk.

## Steg 1: Skaffa Anthropic API-nyckel

1. Gå till https://console.anthropic.com/
2. Skapa ett konto eller logga in
3. Navigera till "API Keys"
4. Skapa en ny API-nyckel och kopiera den

## Steg 2: Konfigurera Claude i MindsDB

Öppna MindsDB Web UI på http://localhost:47334 och kör följande SQL:

```sql
CREATE ML_ENGINE anthropic_engine
FROM anthropic
USING
  api_key = 'din-anthropic-api-nyckel';
```

## Steg 3: Skapa en Claude-modell

### Exempel 1: Bokningsanalys med Claude

```sql
CREATE MODEL awaio_chat_model
PREDICT answer
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Analysera följande bokningsdata och svara på frågan: {{question}}.

  Data: {{context}}';
```

### Exempel 2: Generera insikter från bokningsdata

```sql
CREATE MODEL booking_insights
PREDICT insight
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Baserat på dessa bokningar: {{booking_data}},

  Ge insikter om:
  1. Populäraste tider
  2. Användningsmönster
  3. Rekommendationer för optimering';
```

## Steg 4: Använd Claude för att analysera data

### Fråga om bokningsdata
```sql
SELECT answer
FROM awaio_chat_model
WHERE question = 'Vilka är de mest populära skrivborden under måndagar kl 09-12?'
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

### Få sammanfattning av bokningsdata
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

## Avancerade användningsfall

### 1. Chatbot för bokningshistorik

```sql
CREATE MODEL booking_chatbot
PREDICT response
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Du är en hjälpsam assistent för Awaio-bokningssystemet.

  Bokningsdata: {{booking_context}}

  Användarfråga: {{user_question}}

  Svara på svenska och ge konkreta insikter baserade på datan.';
```

Använd chatten:
```sql
SELECT response
FROM booking_chatbot
WHERE user_question = 'Hur många bokningar hade vi förra veckan jämfört med denna vecka?'
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

### 2. Generera rekommendationer

```sql
CREATE MODEL desk_recommendations
PREDICT recommendation
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Baserat på användarens bokningshistorik: {{user_history}}

  Och tillgängliga skrivbord: {{available_desks}}

  Rekommendera de 3 bästa skrivborden för användaren och förklara varför.';
```

### 3. Anomali-förklaring

```sql
CREATE MODEL anomaly_explainer
PREDICT explanation
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Analysera denna bokning som kan vara ovanlig: {{booking_details}}

  Jämför med normala mönster: {{normal_patterns}}

  Förklara varför denna bokning kan vara ovanlig och om det kräver uppmärksamhet.';
```

### 4. Naturlig språk till SQL

```sql
CREATE MODEL nl_to_sql
PREDICT sql_query
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'Databasschema:
  - bookings (id, entity_id, owner_id, start_time, end_time, status)
  - entities (id, name, group_tag, parent_id)
  - users (id, email, display_name)

  Användares fråga: {{natural_language_query}}

  Generera en korrekt PostgreSQL-query för att svara på frågan.';
```

Använd NL-to-SQL:
```sql
SELECT sql_query
FROM nl_to_sql
WHERE natural_language_query = 'Visa alla bokningar för skrivbord som är längre än 4 timmar';
```

## Kombinera Claude med ML-modeller

### Förklara ML-prediktioner med Claude

```sql
-- Först: Skapa en prediktionsmodell
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

-- Sedan: Använd Claude för att förklara prediktionen
CREATE MODEL prediction_explainer
PREDICT explanation
USING
  engine = 'anthropic_engine',
  model_name = 'claude-3-5-sonnet-20241022',
  prompt_template = 'ML-modellen förutspår: {{prediction}}

  Förklara denna prediktion i enkla termer och ge rekommendationer.';
```

## Python-exempel

```python
import mysql.connector
import os

# Anslut till MindsDB
connection = mysql.connector.connect(
    host='localhost',
    port=47335,
    user='mindsdb',
    password=''
)

cursor = connection.cursor()

# Konfigurera Claude engine
cursor.execute(f"""
    CREATE ML_ENGINE IF NOT EXISTS anthropic_engine
    FROM anthropic
    USING
      api_key = '{os.getenv("ANTHROPIC_API_KEY")}';
""")

# Skapa en chatbot-modell
cursor.execute("""
    CREATE MODEL IF NOT EXISTS booking_chat
    PREDICT response
    USING
      engine = 'anthropic_engine',
      model_name = 'claude-3-5-sonnet-20241022',
      prompt_template = 'Bokningsdata: {{data}}

      Fråga: {{question}}

      Svara på svenska.';
""")

# Ställ en fråga
question = "Vilka skrivbord är mest populära?"
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
print(f"Claude svarar: {result[0]}")

cursor.close()
connection.close()
```

## Miljövariabler

Lägg till din Anthropic API-nyckel i `.env`:

```bash
# Anthropic API Configuration
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
```

## Tips och bästa praxis

1. **Välj rätt Claude-modell**:
   - `claude-3-5-sonnet-20241022`: Bäst balans mellan hastighet och kvalitet
   - `claude-3-opus-20240229`: Högsta kvalitet, långsammare
   - `claude-3-haiku-20240307`: Snabbast, för enklare uppgifter

2. **Optimera prompts**:
   - Var specifik i dina instruktioner
   - Inkludera exempel i prompt_template
   - Begränsa datamängd till relevanta fält

3. **Hantera kostnader**:
   - Cacha ofta använda queries
   - Använd Haiku för enkla uppgifter
   - Begränsa context-storlek

4. **Säkerhet**:
   - Lagra API-nycklar i miljövariabler
   - Använd aldrig hårdkodade nycklar
   - Begränsa åtkomst till MindsDB

## Felsökning

### Kontrollera att engine är skapad
```sql
SHOW ML_ENGINES;
```

### Lista alla modeller
```sql
SHOW MODELS;
```

### Se modelldetaljer
```sql
DESCRIBE booking_chat;
```

### Testa anslutning
```sql
SELECT *
FROM anthropic_engine
WHERE prompt = 'Säg hej!';
```

## Resurser

- [MindsDB + Anthropic Documentation](https://docs.mindsdb.com/integrations/ai-engines/anthropic)
- [Claude API Documentation](https://docs.anthropic.com/)
- [MindsDB AI Tables](https://docs.mindsdb.com/sql/tutorials/ai-tables)
