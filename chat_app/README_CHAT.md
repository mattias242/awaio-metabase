# Awaio AI Chat App 💬

A web-based chat application for talking to your booking data via AI agents (Google Gemini or OpenAI).

## Overview

A Streamlit-based chat interface that connects to MindsDB and lets you ask natural-language questions about your booking system.

## Quick start

### 1. Start the chat app

```bash
# From the Awaio root directory
docker-compose up -d chat
```

### 2. Open it in the browser

Go to: **http://localhost:8501**

### 3. Start chatting!

Ask questions such as:
- "Which weekday has the most bookings?"
- "Which desk is the most popular?"
- "Give me a weekly report"
- "Which resources are under-used?"

## Prerequisites

### MindsDB must be configured

Before you can use the chat app you need to have:

1. ✅ Created the Gemini ML engine
2. ✅ Created the `awaio_gemini_agent` model

See [GEMINI_SETUP.md](../mindsdb/GEMINI_SETUP.md) for the full setup.

### Quick check

Check that the agent works in the MindsDB Web UI (http://localhost:47334):

```sql
SELECT answer
FROM awaio_gemini_agent
WHERE question = 'Hello, are you working?'
```

If this gives you an answer, you are ready to use the chat app!

## Features

### 🎨 Interface

- **ChatGPT-like UI**: modern chat bubbles with timestamps
- **Conversation history**: all questions and answers are kept for the session
- **Example questions**: clickable suggestions when you start a new chat
- **Agent picker**: switch between Gemini and OpenAI in the sidebar

### 🤖 AI agents

The chat app supports the following agents:

1. **Gemini Agent** (recommended)
   - Model: `awaio_gemini_agent`
   - Free tier: 60 requests/minute
   - Fast and multilingual

2. **OpenAI Agent**
   - Model: `awaio_chat_agent`
   - Requires an OpenAI API key
   - GPT-4 quality

### 📊 Data access

The agent has access to:
- **Bookings**: all bookings with start_time, end_time, owner_id
- **Entities**: desks, rooms, lockers with their hierarchy
- **Users**: user information (pseudonymised)
- **57 desks** spread over 3 floors + Tillsammansytan

## Usage

### Start/stop

```bash
# Start the chat app
docker-compose up -d chat

# Stop the chat app
docker-compose stop chat

# Show the logs
docker-compose logs -f chat

# Rebuild after changes
docker-compose up -d --build chat
```

### Switching agent

1. Open the sidebar (⚙️ Settings)
2. Choose an agent from the dropdown
3. Keep chatting (the history is kept)

### Clearing the chat

Click "🗑️ Clear chat" in the sidebar to start over with a new conversation.

## Architecture

```
┌──────────────┐
│   Browser    │  http://localhost:8501
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

## Example questions

### Trends

- "Which weekday has the most bookings?"
- "What does the booking pattern look like for the last 30 days?"
- "Are there any trends I should know about?"

### Statistics

- "How many bookings do we have in total?"
- "Which desk is the most popular?"
- "Which days have the least activity?"

### Recommendations

- "Give me a weekly report"
- "Which resources are under-used?"
- "How can we improve resource utilisation?"

### Analysis

- "Analyse this week's bookings and give recommendations"
- "Which desks on Plan 2 are used the most?"
- "Are there any booking conflicts?"

## Troubleshooting

### The chat app does not start

**Problem**: `docker-compose up -d chat` fails

**Solutions**:

1. Check that MindsDB is running:
   ```bash
   docker-compose ps
   ```

2. Check the logs:
   ```bash
   docker-compose logs chat
   ```

3. Rebuild:
   ```bash
   docker-compose up -d --build chat
   ```

### "Could not connect to MindsDB"

**Problem**: the chat app cannot reach MindsDB

**Solutions**:

1. Verify that MindsDB is running:
   ```bash
   curl http://localhost:47334
   ```

2. Check the Docker network:
   ```bash
   docker network inspect awaio_awaio-network
   ```

3. Restart both containers:
   ```bash
   docker-compose restart mindsdb chat
   ```

### "Could not get an answer from the AI agent"

**Problem**: the agent returns an empty answer

**Solutions**:

1. Verify that the agent is trained:
   ```sql
   DESCRIBE awaio_gemini_agent;
   ```
   The status should be "complete"

2. Test directly in the MindsDB Web UI:
   ```sql
   SELECT answer
   FROM awaio_gemini_agent
   WHERE question = 'Test'
   ```

3. Check that the Gemini API key is correct in the ML_ENGINE

### Answers in the wrong language

**Problem**: the agent answers in a different language than the question

**Solution**: update the prompt_template in `awaio_gemini_agent`:

```sql
DROP MODEL awaio_gemini_agent;

CREATE MODEL awaio_gemini_agent
PREDICT answer
USING
  engine = 'gemini_engine',
  model_name = 'gemini-2.5-flash',
  prompt_template = 'Answer ONLY in English. {{question}}';
```

### Port 8501 is already in use

**Problem**: another app is running on port 8501

**Solution**: change the port in `.env`:

```bash
echo "CHAT_PORT=8502" >> .env
docker-compose up -d chat
```

Then open http://localhost:8502

## Customisation

### Changing the UI theme

Edit `chat_app.py`:

```python
st.set_page_config(
    page_title="Awaio AI Chat",
    page_icon="💬",
    layout="wide",
    initial_sidebar_state="expanded"  # or "collapsed"
)
```

### Adding more agents

1. Create a new agent in MindsDB (see [GEMINI_SETUP.md](../mindsdb/GEMINI_SETUP.md))

2. Update `chat_app.py`:
   ```python
   agent_options = {
       'awaio_gemini_agent': 'Gemini Agent',
       'awaio_chat_agent': 'OpenAI Agent',
       'your_new_agent': 'My Custom Agent'
   }
   ```

3. Rebuild and restart:
   ```bash
   docker-compose up -d --build chat
   ```

### Changing the example questions

Edit `chat_app.py` near the bottom, where the button widgets are created:

```python
if st.button("📊 Your new question?", use_container_width=True):
    st.session_state.messages.append({
        "role": "user",
        "content": "Your question here",
        "timestamp": datetime.now().strftime("%H:%M:%S")
    })
    st.rerun()
```

## Development

### Local development (without Docker)

```bash
cd chat_app

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export MINDSDB_HOST=localhost
export MINDSDB_PORT=47334

# Run Streamlit
streamlit run chat_app.py
```

### Live reload

Streamlit has built-in live reload. When you change `chat_app.py`, "Rerun" appears in the browser.

### Debugging

Add debug output to `chat_app.py`:

```python
st.write("Debug info:", result_df)
```

## Security

⚠️ **Important:**

- The chat app does NOT expose your Gemini API key
- API keys are stored in the MindsDB container
- The chat app only talks to MindsDB via SQL
- NEVER use this setup in production without authentication

For production, add:
- User authentication (Streamlit Auth)
- HTTPS (reverse proxy with nginx)
- Rate limiting
- Input sanitisation

## Performance

### Response times

- **Gemini Pro**: 2-5 seconds
- **OpenAI GPT-4**: 3-8 seconds

### Limits

- **Free Gemini**: 60 requests/minute
- **Streamlit**: max 1000 concurrent users (free)

### Optimisation

For faster answers:
1. Use shorter prompts
2. Limit the data context
3. Cache common questions
4. Upgrade to Gemini 1.5 Flash

## Next steps

1. ✅ Start the chat app: `docker-compose up -d chat`
2. ✅ Open http://localhost:8501
3. ✅ Start chatting with your data
4. 🚀 Integrate it into your own app
5. 🚀 Add more AI agents
6. 🚀 Build custom widgets and dashboards

## Support

If you run into problems:

1. Check the troubleshooting section above
2. Read [GEMINI_SETUP.md](../mindsdb/GEMINI_SETUP.md)
3. Check the MindsDB logs: `docker-compose logs -f mindsdb`
4. Test the agent directly in the MindsDB Web UI first

**Good luck with your AI-powered chat! 🚀💬**
