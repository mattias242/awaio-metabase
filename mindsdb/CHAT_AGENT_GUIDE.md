# AI Chat Agent för Awaio Bokningsdata

## Översikt
Skapa en konversationsagent som kan svara på frågor om dina bokningar på svenska.

## Setup

### Alternativ 1: Med OpenAI (Kräver API Key)

```sql
-- 1. Konfigurera OpenAI ML Engine först
CREATE ML_ENGINE openai_engine
FROM openai
USING
  api_key = 'din-openai-api-key';

-- 2. Skapa chat-agenten
CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'openai_engine',
  model_name = 'gpt-4',
  prompt_template = 'Du är en hjälpsam assistent som analyserar bokningsdata.

  Användaren frågar: {{question}}

  Svara på svenska och var konkret.';
```

### Alternativ 2: Med Hugging Face (Gratis)

```sql
-- Kräver ingen API key, använder öppen modell
CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'huggingface',
  task = 'text-generation',
  model_name = 'mistralai/Mistral-7B-Instruct-v0.2',
  input_column = 'question';
```

### Alternativ 3: Med Local LLM (Ollama)

```sql
-- Om du kör Ollama lokalt
CREATE ML_ENGINE ollama_engine
FROM ollama
USING
  host = 'host.docker.internal:11434';

CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'ollama_engine',
  model_name = 'llama2',
  prompt_template = 'Svara på svenska: {{question}}';
```

## Användning

### Enkel fråga
```sql
SELECT answer
FROM awaio_chat_agent
WHERE question = 'Hur många bokningar har vi denna vecka?'
```

### Flera frågor
```sql
SELECT
  t.question,
  m.answer
FROM (
  SELECT 'Vilken veckodag har flest bokningar?' AS question
  UNION ALL
  SELECT 'Vilket rum är mest populärt?'
  UNION ALL
  SELECT 'Vad är genomsnittlig bokningstid?'
) AS t
JOIN awaio_chat_agent AS m
```

### Fråga med faktisk data
```sql
-- Kombinera faktisk statistik med AI-svar
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
WHERE m.question = 'Analysera vårt bokningsmönster baserat på statistiken'
```

## Avancerade Use Cases

### 1. Automatisk Rapport

```sql
-- Generera veckorapport
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
  'Skapa en kort veckorapport. Denna vecka: ',
  CAST(stats.this_week AS VARCHAR),
  ' bokningar. Förra veckan: ',
  CAST(stats.last_week AS VARCHAR),
  ' bokningar.'
)
```

### 2. Rekommendationer

```sql
-- Få rekommendationer baserat på underutnyttjande
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
WHERE m.question = 'Ge mig rekommendationer för underutnyttjade resurser'
```

### 3. Trend-analys

```sql
-- Analysera trender
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
WHERE m.question = 'Analysera trenden i bokningar de senaste 4 veckorna'
```

## Kombinera med RAG (Retrieval Augmented Generation)

För att göra agenten mer intelligent kan du kombinera med en knowledge base:

```sql
-- Skapa en knowledge base med dokumentation
CREATE MODEL awaio_knowledge
PREDICT answer
USING
  engine = 'openai_engine',
  mode = 'conversational',
  user_column = 'question',
  assistant_column = 'answer',
  prompt_template = 'Kontext om Awaio:

  - Vi har 57 skrivbord fördelade på 3 våningar
  - Plan 1: 15 skrivbord
  - Plan 2: 18 skrivbord
  - Plan 3: 24 skrivbord
  - Tillsammansytan: 8 skrivbord

  Fråga: {{question}}';
```

## Troubleshooting

### "ML_ENGINE not found"
**Lösning:** Skapa ML_ENGINE först för OpenAI/Ollama

### "API key invalid"
**Lösning:** Kontrollera din OpenAI API key

### Långsamma svar
**Lösning:**
- Använd mindre modell (gpt-3.5-turbo istället för gpt-4)
- Eller använd lokal Ollama

### Svar på engelska
**Lösning:** Lägg till "Svara ALLTID på svenska" i prompt_template

## Best Practices

1. **Tydliga prompts**: Specificera språk och format
2. **Begränsa context**: För stora datamängder, aggregera först
3. **Cache resultat**: Spara vanliga frågor som VIEWs
4. **Säkerhet**: Exponera inte känslig data i prompts

## Nästa Steg

1. Välj LLM-provider (OpenAI, Hugging Face, eller Ollama)
2. Skapa ML_ENGINE (om behövs)
3. Skapa chat-agenten med [05_create_chat_agent.sql](05_create_chat_agent.sql)
4. Testa med [06_use_chat_agent.sql](06_use_chat_agent.sql)
5. Integrera i Metabase eller egen app

## Integration med Metabase

Du kan skapa "Question Cards" i Metabase som kör dessa queries:

```sql
-- Metabase Question: "Veckans sammanfattning"
SELECT answer FROM awaio_chat_agent
WHERE question = 'Sammanfatta veckans bokningar'
```

Detta skapar en auto-genererad text-widget i din dashboard! 📊
