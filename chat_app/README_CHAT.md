# Awaio AI Chat App 💬

En webbaserad chattapplikation för att prata med din bokningsdata via AI-agenter (Google Gemini eller OpenAI).

## Översikt

Streamlit-baserad chat-interface som kopplar till MindsDB och låter dig ställa frågor på naturligt språk om ditt bokningssystem.

## Snabbstart

### 1. Starta Chat-appen

```bash
# Från Awaio root-katalogen
docker-compose up -d chat
```

### 2. Öppna i webbläsaren

Gå till: **http://localhost:8501**

### 3. Börja chatta!

Ställ frågor som:
- "Vilken veckodag har flest bokningar?"
- "Vilket skrivbord är mest populärt?"
- "Ge mig en veckorapport"
- "Vilka resurser är underutnyttjade?"

## Förutsättningar

### MindsDB måste vara konfigurerad

Innan du kan använda chat-appen måste du ha:

1. ✅ Skapat Gemini ML Engine
2. ✅ Skapat `awaio_gemini_agent` modell

Se [GEMINI_SETUP.md](../mindsdb/GEMINI_SETUP.md) för fullständig setup.

### Snabb verifiering

Kontrollera att agenten fungerar i MindsDB Web UI (http://localhost:47334):

```sql
SELECT answer
FROM awaio_gemini_agent
WHERE question = 'Hej, fungerar du?'
```

Om detta ger ett svar på svenska är du redo att använda chat-appen!

## Funktioner

### 🎨 Gränssnitt

- **ChatGPT-liknande UI**: Moderna chat-bubblor med tidsstämplar
- **Konversationshistorik**: Alla frågor och svar sparas i sessionen
- **Exempel-frågor**: Klickbara förslag när du startar en ny chat
- **Agent-väljare**: Byt mellan Gemini och OpenAI i sidopanelen

### 🤖 AI-Agenter

Chat-appen stödjer följande agenter:

1. **Gemini Agent** (Rekommenderad)
   - Modell: `awaio_gemini_agent`
   - Gratis tier: 60 requests/minut
   - Snabb och bra på svenska

2. **OpenAI Agent**
   - Modell: `awaio_chat_agent`
   - Kräver OpenAI API key
   - GPT-4 kvalitet

### 📊 Dataåtkomst

Agenten har tillgång till:
- **Bookings**: Alla bokningar med start_time, end_time, owner_id
- **Entities**: Skrivbord, rum, skåp med hierarki
- **Users**: Användarinformation
- **57 skrivbord** fördelade på 3 våningar + Tillsammansytan

## Användning

### Starta/Stoppa

```bash
# Starta chat-appen
docker-compose up -d chat

# Stoppa chat-appen
docker-compose stop chat

# Se loggar
docker-compose logs -f chat

# Rebuild efter ändringar
docker-compose up -d --build chat
```

### Byta Agent

1. Öppna sidopanelen (⚙️ Inställningar)
2. Välj agent från dropdown-menyn
3. Fortsätt chatta (historiken bevaras)

### Rensa Chat

Klicka på "🗑️ Rensa chat" i sidopanelen för att börja om med en ny konversation.

## Arkitektur

```
┌──────────────┐
│  Webbläsare  │  http://localhost:8501
└──────┬───────┘
       │
       ↓
┌──────────────┐
│  Streamlit   │  (awaio-chat container)
│   Chat App   │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│   MindsDB    │  (awaio-mindsdb container)
│ SQL Interface│
└──────┬───────┘
       │
       ├─→ Google Gemini API (gemini-2.5-flash)
       │
       └─→ PostgreSQL (awaio_postgres)
```

## Exempel Frågor

### Trender

- "Vilken veckodag har flest bokningar?"
- "Hur ser bokningsmönstret ut för de senaste 30 dagarna?"
- "Finns det några trender jag bör känna till?"

### Statistik

- "Hur många bokningar har vi totalt?"
- "Vilket skrivbord är mest populärt?"
- "Vilka dagar har minst aktivitet?"

### Rekommendationer

- "Ge mig en veckorapport"
- "Vilka resurser är underutnyttjade?"
- "Hur kan vi förbättra resursutnyttjandet?"

### Analys

- "Analysera veckans bokningar och ge rekommendationer"
- "Vilka skrivbord på Plan 2 används mest?"
- "Finns det några bokningskonflikter?"

## Felsökning

### Chat-appen startar inte

**Problem**: `docker-compose up -d chat` failar

**Lösningar**:

1. Kontrollera att MindsDB är igång:
   ```bash
   docker-compose ps
   ```

2. Kolla loggar:
   ```bash
   docker-compose logs chat
   ```

3. Rebuild:
   ```bash
   docker-compose up -d --build chat
   ```

### "Kunde inte ansluta till MindsDB"

**Problem**: Chat-appen kan inte nå MindsDB

**Lösningar**:

1. Verifiera att MindsDB är igång:
   ```bash
   curl http://localhost:47334
   ```

2. Kontrollera Docker network:
   ```bash
   docker network inspect awaio_awaio-network
   ```

3. Restart båda containers:
   ```bash
   docker-compose restart mindsdb chat
   ```

### "Kunde inte få svar från AI-agenten"

**Problem**: Agenten returnerar tomt svar

**Lösningar**:

1. Verifiera att agenten är tränad:
   ```sql
   DESCRIBE awaio_gemini_agent;
   ```
   Status ska vara "complete"

2. Testa direkt i MindsDB Web UI:
   ```sql
   SELECT answer
   FROM awaio_gemini_agent
   WHERE question = 'Test'
   ```

3. Kontrollera att Gemini API key är korrekt i ML_ENGINE

### Svar på engelska

**Problem**: Agenten svarar på engelska trots svensk fråga

**Lösning**: Uppdatera prompt_template i `awaio_gemini_agent`:

```sql
DROP MODEL awaio_gemini_agent;

CREATE MODEL awaio_gemini_agent
PREDICT answer
USING
  engine = 'gemini_engine',
  model_name = 'gemini-2.5-flash',
  prompt_template = 'Svara UTESLUTANDE på svenska. {{question}}';
```

### Port 8501 redan används

**Problem**: Annan app kör på port 8501

**Lösning**: Ändra port i `.env`:

```bash
echo "CHAT_PORT=8502" >> .env
docker-compose up -d chat
```

Öppna sedan http://localhost:8502

## Anpassning

### Ändra UI-temat

Redigera `chat_app.py`:

```python
st.set_page_config(
    page_title="Awaio AI Chat",
    page_icon="💬",
    layout="wide",
    initial_sidebar_state="expanded"  # eller "collapsed"
)
```

### Lägga till fler agenter

1. Skapa ny agent i MindsDB (se [GEMINI_SETUP.md](../mindsdb/GEMINI_SETUP.md))

2. Uppdatera `chat_app.py`:
   ```python
   agent_options = {
       'awaio_gemini_agent': 'Gemini Agent',
       'awaio_chat_agent': 'OpenAI Agent',
       'din_nya_agent': 'Min Custom Agent'
   }
   ```

3. Rebuild och restart:
   ```bash
   docker-compose up -d --build chat
   ```

### Ändra exempel-frågor

Redigera `chat_app.py` längst ner där button-widgets skapas:

```python
if st.button("📊 Din nya fråga?", use_container_width=True):
    st.session_state.messages.append({
        "role": "user",
        "content": "Din fråga här",
        "timestamp": datetime.now().strftime("%H:%M:%S")
    })
    st.rerun()
```

## Development

### Local Development (utan Docker)

```bash
cd chat_app

# Installera dependencies
pip install -r requirements.txt

# Sätt miljövariabler
export MINDSDB_HOST=localhost
export MINDSDB_PORT=47334

# Kör Streamlit
streamlit run chat_app.py
```

### Live Reload

Streamlit har inbyggd live reload. När du ändrar `chat_app.py` visas "Rerun" i webbläsaren.

### Debugging

Lägg till debug-output i `chat_app.py`:

```python
st.write("Debug info:", result_df)
```

## Säkerhet

⚠️ **Viktigt:**

- Chat-appen exponerar INTE din Gemini API key
- API keys lagras i MindsDB-containern
- Chat-appen pratar bara med MindsDB via SQL
- Använd ALDRIG denna setup i produktion utan autentisering

För produktion, lägg till:
- User authentication (Streamlit Auth)
- HTTPS (reverse proxy med nginx)
- Rate limiting
- Input sanitization

## Prestanda

### Response Times

- **Gemini Pro**: 2-5 sekunder
- **OpenAI GPT-4**: 3-8 sekunder

### Begränsningar

- **Gratis Gemini**: 60 requests/minut
- **Streamlit**: Max 1000 samtida användare (gratis)

### Optimering

För snabbare svar:
1. Använd kortare prompts
2. Begränsa datakontext
3. Cache vanliga frågor
4. Uppgradera till Gemini 1.5 Flash

## Nästa Steg

1. ✅ Starta chat-appen: `docker-compose up -d chat`
2. ✅ Öppna http://localhost:8501
3. ✅ Börja chatta med din data
4. 🚀 Integrera i din egen app
5. 🚀 Lägg till fler AI-agenter
6. 🚀 Skapa custom widgets och dashboards

## Support

Om du stöter på problem:

1. Kolla felsökningssektionen ovan
2. Läs [GEMINI_SETUP.md](../mindsdb/GEMINI_SETUP.md)
3. Kontrollera MindsDB logs: `docker-compose logs -f mindsdb`
4. Testa agenten direkt i MindsDB Web UI först

**Lycka till med din AI-powered chat! 🚀💬**
