# Google Gemini AI Agent Setup för Awaio

## Steg 1: Skaffa Gemini API Key

1. Gå till: **https://aistudio.google.com/app/apikey**
2. Logga in med ditt Google-konto
3. Klicka "Create API Key"
4. Kopiera din API key (börjar med `AIza...`)

## Steg 2: Skapa ML Engine i MindsDB

Öppna MindsDB Web UI (http://localhost:47334) och kör:

```sql
CREATE ML_ENGINE gemini_engine
FROM google_gemini
USING
  google_gemini_api_key = 'AIza...DIN-API-KEY-HÄR';
```

**Förväntat resultat:** "Query successfully completed"

## Steg 3: Skapa Chat-Agenten

Kör [05a_create_gemini_agent.sql](05a_create_gemini_agent.sql) eller kör denna SQL:

```sql
CREATE MODEL awaio_gemini_agent
PREDICT answer
USING
  engine = 'gemini_engine',
  model_name = 'gemini-2.5-flash',
  prompt_template = 'Du är en hjälpsam assistent som analyserar bokningsdata.

  Användaren frågar: {{question}}

  Svara ALLTID på svenska och var konkret.';
```

**OBS:** Detta tar 10-30 sekunder första gången.

## Steg 4: Testa Agenten

### Enkel fråga
```sql
SELECT answer
FROM awaio_gemini_agent
WHERE question = 'Vilken veckodag har flest bokningar?'
```

### Flera frågor samtidigt
```sql
SELECT
  t.question,
  m.answer
FROM (
  SELECT 'Hur många bokningar har vi totalt?' AS question
  UNION ALL
  SELECT 'Vilket skrivbord är mest populärt?'
  UNION ALL
  SELECT 'Vilka dagar har minst aktivitet?'
) AS t
JOIN awaio_gemini_agent AS m
```

### Fråga med faktisk statistik
```sql
SELECT
  'Totalt: ' || stats.total_bookings || ' bokningar' AS statistik,
  m.answer AS ai_analys
FROM awaio_gemini_agent AS m
JOIN (
  SELECT
    COUNT(*) as total_bookings,
    COUNT(DISTINCT owner_id) as unique_users,
    COUNT(DISTINCT entity_id) as unique_resources
  FROM awaio_postgres.bookings
) AS stats
WHERE m.question = CONCAT(
  'Vi har totalt ',
  CAST(stats.total_bookings AS VARCHAR),
  ' bokningar från ',
  CAST(stats.unique_users AS VARCHAR),
  ' unika användare över ',
  CAST(stats.unique_resources AS VARCHAR),
  ' olika resurser. Analysera detta och ge rekommendationer.'
)
```

## Steg 5: Avancerade Use Cases

### A. Veckorapport
```sql
SELECT m.answer AS veckorapport
FROM awaio_gemini_agent AS m
WHERE m.question = 'Skapa en kort sammanfattning av veckans bokningar och trender'
```

### B. Underutnyttjade Resurser
```sql
SELECT
  e.name AS resurs,
  COUNT(b.id) AS antal_bokningar,
  m.answer AS rekommendation
FROM awaio_postgres.entities e
LEFT JOIN awaio_postgres.bookings b ON e.id = b.entity_id
JOIN awaio_gemini_agent m
WHERE e.group_tag = 'desk'
  AND m.question = CONCAT(
    'Resursen "', e.name, '" har endast ',
    CAST(COUNT(b.id) AS VARCHAR),
    ' bokningar. Ge rekommendationer för hur vi kan öka utnyttjandet.'
  )
GROUP BY e.name
HAVING COUNT(b.id) < 10
```

### C. Trend-Analys
```sql
SELECT m.answer AS trendanalys
FROM awaio_gemini_agent m
JOIN (
  SELECT
    EXTRACT(DOW FROM start_time) as veckodag,
    COUNT(*) as antal
  FROM awaio_postgres.bookings
  WHERE start_time >= NOW() - INTERVAL '30 days'
  GROUP BY veckodag
  ORDER BY veckodag
) trends
WHERE m.question = 'Analysera bokningsmönster per veckodag och identifiera trender'
```

## Integration med Metabase

Skapa "Native Query" widgets i Metabase:

### Widget 1: AI Insights
```sql
SELECT answer AS "AI Analys"
FROM awaio_gemini_agent
WHERE question = 'Sammanfatta de viktigaste insikterna från bokningsdata'
```

### Widget 2: Rekommendationer
```sql
SELECT answer AS "Rekommendationer"
FROM awaio_gemini_agent
WHERE question = 'Ge 3 konkreta rekommendationer för att förbättra resursutnyttjandet'
```

## Gemini-Specifika Fördelar

✅ **Gratis tier** - 60 requests/minut
✅ **Multimodal** - Kan hantera text, bilder, och mer
✅ **Snabb** - Ofta snabbare än GPT-4
✅ **Långa kontext** - Upp till 1M tokens (Gemini 1.5 Pro)
✅ **Svenskt språk** - Bra stöd för svenska

## Modellval

MindsDB stödjer olika Gemini-modeller (2025):

```sql
-- Gemini 2.5 Flash (Rekommenderad - snabb och modern)
model_name = 'gemini-2.5-flash'

-- Gemini 2.5 Pro (Längre kontext och mer avancerad)
model_name = 'gemini-2.5-pro'

-- Gemini 2.0 Flash (Äldre version)
model_name = 'gemini-2.0-flash'
```

**OBS:** Äldre modeller som `gemini-pro` och `gemini-1.5-pro` är föråldrade sedan 2025.

## Troubleshooting

### "ML_ENGINE not found"
**Problem:** Gemini engine inte skapad
**Lösning:** Kör CREATE ML_ENGINE först

### "Invalid API key"
**Problem:** Fel API key eller inte aktiverad
**Lösning:**
1. Kontrollera key från https://aistudio.google.com/app/apikey
2. Säkerställ att Gemini API är aktiverat för ditt projekt

### "Rate limit exceeded"
**Problem:** För många requests
**Lösning:** Vänta 1 minut eller uppgradera till betald plan

### Svar på engelska
**Problem:** Gemini svarar på engelska trots prompt
**Lösning:** Lägg till "Svara UTESLUTANDE på svenska" i början av prompt_template

### Långsamma svar
**Problem:** Tar lång tid att få svar
**Lösning:**
- Använd kortare prompts
- Begränsa datamängd i JOIN
- Överväg caching av vanliga frågor

## Kostnader

Gemini har en generös **gratis tier**:

- **Gemini Pro**: 60 requests/minut gratis
- **Gemini 1.5 Pro**: 2 requests/minut gratis
- **Gemini 1.5 Flash**: 15 requests/minut gratis

För production, se: https://ai.google.dev/pricing

## Säkerhet

⚠️ **Viktigt:**
- Exponera ALDRIG API keys i version control
- Använd miljövariabler för API keys
- Begränsa API key till specifika IP-adresser om möjligt
- Logga aldrig känslig användardata i prompts

## Nästa Steg

1. ✅ Skaffa Gemini API key
2. ✅ Skapa ML_ENGINE i MindsDB
3. ✅ Skapa awaio_gemini_agent modell
4. ✅ Testa med enkla frågor
5. ✅ Integrera i Metabase dashboards
6. ✅ Bygg custom chat-interface (optional)

**Lycka till med din AI-agent! 🚀**
