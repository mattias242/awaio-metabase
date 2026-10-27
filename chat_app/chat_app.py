import streamlit as st
import mindsdb_sdk
import os
from datetime import datetime

# Page configuration
st.set_page_config(
    page_title="Awaio AI Chat",
    page_icon="💬",
    layout="wide"
)

# Initialize connection to MindsDB
@st.cache_resource
def get_mindsdb_connection():
    """Connect to MindsDB server"""
    try:
        # MindsDB SDK 3.x uses url parameter
        mindsdb_url = f"http://{os.getenv('MINDSDB_HOST', 'mindsdb')}:{os.getenv('MINDSDB_PORT', '47334')}"
        server = mindsdb_sdk.connect(mindsdb_url)
        return server
    except Exception as e:
        st.error(f"Failed to connect to MindsDB: {e}")
        return None

# Initialize session state
if 'messages' not in st.session_state:
    st.session_state.messages = []

if 'selected_agent' not in st.session_state:
    st.session_state.selected_agent = 'awaio_agent'  # MindsDB Agent (autonomous)

# Sidebar
with st.sidebar:
    st.title("⚙️ Inställningar")

    # Agent selector
    agent_options = {
        'awaio_agent': 'Awaio Agent (Autonom med SQL)',
        'awaio_gemini_agent': 'Gemini Model (Basic)',
        'awaio_chat_agent': 'OpenAI Model'
    }

    selected = st.selectbox(
        "Välj AI-agent:",
        options=list(agent_options.keys()),
        format_func=lambda x: agent_options[x],
        index=0
    )
    st.session_state.selected_agent = selected

    st.divider()

    # Clear chat button
    if st.button("🗑️ Rensa chat", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

    st.divider()

    # Info section
    st.markdown("### 📊 Om Awaio AI")
    st.markdown("""
    Denna chat-agent analyserar bokningsdata från Awaio systemet.

    **Databas:**
    - 57 skrivbord
    - 3 våningar + Tillsammansytan
    - Bokningshistorik
    - Användardata

    **Fråga mig om:**
    - Bokningstrender
    - Resursutnyttjande
    - Populära skrivbord
    - Veckodagsanalys
    - Rekommendationer
    """)

# Main chat interface
st.title("💬 Awaio AI Chat")
st.markdown(f"Chatta med din bokningsdata via **{agent_options[st.session_state.selected_agent]}**")

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if "timestamp" in message:
            st.caption(message["timestamp"])

# Chat input
if prompt := st.chat_input("Ställ en fråga om bokningsdata..."):
    # Add user message to chat
    timestamp = datetime.now().strftime("%H:%M:%S")
    st.session_state.messages.append({
        "role": "user",
        "content": prompt,
        "timestamp": timestamp
    })

    # Display user message
    with st.chat_message("user"):
        st.markdown(prompt)
        st.caption(timestamp)

    # Get AI response
    with st.chat_message("assistant"):
        message_placeholder = st.empty()
        message_placeholder.markdown("🤔 Analyserar data...")

        try:
            # Connect to MindsDB
            server = get_mindsdb_connection()

            if server is None:
                response = "❌ Kunde inte ansluta till MindsDB. Kontrollera att MindsDB-containern körs."
            else:
                # Check if using autonomous agent or basic model
                if st.session_state.selected_agent == 'awaio_agent':
                    # Autonomous Agent - it handles SQL automatically!
                    query = f"""
                    SELECT * FROM awaio_agent
                    WHERE question = '{prompt.replace("'", "''")}'
                    """

                    # Execute and get result
                    query_result = server.query(query)
                    result_df = query_result.fetch()

                else:
                    # Basic Model - we need to provide data via JOIN
                    prompt_lower = prompt.lower()

                    if any(word in prompt_lower for word in ['populär', 'mest bokad', 'bäst', 'skrivbord']):
                        query = f"""
                        SELECT m.answer
                        FROM {st.session_state.selected_agent} m
                        JOIN (
                            SELECT e.name, COUNT(b.id) as bookings
                            FROM awaio_postgres.entities e
                            LEFT JOIN awaio_postgres.bookings b ON e.id = b.entity_id
                            WHERE e.group_tag = 'desk'
                            GROUP BY e.name
                            ORDER BY bookings DESC
                            LIMIT 10
                        ) data
                        WHERE m.question = 'Här är data om skrivbordspopularitet. Besvara användarens fråga: "{prompt.replace("'", "''")}" - Svara KORT (max 2 meningar) med konkreta namn och siffror.'
                        """

                    elif any(word in prompt_lower for word in ['veckodag', 'dag', 'veckodagar']):
                        query = f"""
                        SELECT m.answer
                        FROM {st.session_state.selected_agent} m
                        JOIN (
                            SELECT
                                CASE EXTRACT(DOW FROM start_time)
                                    WHEN 0 THEN 'Söndag'
                                    WHEN 1 THEN 'Måndag'
                                    WHEN 2 THEN 'Tisdag'
                                    WHEN 3 THEN 'Onsdag'
                                    WHEN 4 THEN 'Torsdag'
                                    WHEN 5 THEN 'Fredag'
                                    WHEN 6 THEN 'Lördag'
                                END as weekday,
                                COUNT(*) as bookings
                            FROM awaio_postgres.bookings
                            GROUP BY EXTRACT(DOW FROM start_time)
                            ORDER BY bookings DESC
                        ) data
                        WHERE m.question = 'Här är bokningsdata per veckodag. Besvara: "{prompt.replace("'", "''")}" - Svara KORT (max 2 meningar).'
                        """

                    elif any(word in prompt_lower for word in ['total', 'hur många', 'antal']):
                        query = f"""
                        SELECT m.answer
                        FROM {st.session_state.selected_agent} m
                        JOIN (
                            SELECT
                                COUNT(*) as total_bookings,
                                COUNT(DISTINCT owner_id) as unique_users,
                                COUNT(DISTINCT entity_id) as unique_resources
                            FROM awaio_postgres.bookings
                        ) data
                        WHERE m.question = 'Här är total statistik. Besvara: "{prompt.replace("'", "''")}" - Svara KORT (max 2 meningar).'
                        """

                    else:
                        query = f"""
                        SELECT answer
                        FROM {st.session_state.selected_agent}
                        WHERE question = '{prompt.replace("'", "''")}'
                        """

                    # Execute and get result
                    query_result = server.query(query)
                    result_df = query_result.fetch()

                if result_df is not None and not result_df.empty and 'answer' in result_df.columns:
                    response = str(result_df['answer'].iloc[0])
                else:
                    response = "❌ Kunde inte få svar från AI-agenten. Kontrollera att modellen är tränad och redo."

        except Exception as e:
            response = f"❌ Ett fel uppstod: {str(e)}"

        # Display response
        message_placeholder.markdown(response)
        timestamp = datetime.now().strftime("%H:%M:%S")
        st.caption(timestamp)

        # Add assistant message to chat
        st.session_state.messages.append({
            "role": "assistant",
            "content": response,
            "timestamp": timestamp
        })

# Example questions
if len(st.session_state.messages) == 0:
    st.markdown("### 💡 Exempel på frågor:")

    col1, col2 = st.columns(2)

    with col1:
        if st.button("📊 Vilken veckodag har flest bokningar?", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Vilken veckodag har flest bokningar?",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()

        if st.button("🏢 Vilket skrivbord är mest populärt?", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Vilket skrivbord är mest populärt?",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()

    with col2:
        if st.button("📈 Ge mig en veckorapport", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Skapa en kort sammanfattning av veckans bokningar och trender",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()

        if st.button("💡 Vilka resurser är underutnyttjade?", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Vilka resurser är underutnyttjade och vad rekommenderar du?",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()
