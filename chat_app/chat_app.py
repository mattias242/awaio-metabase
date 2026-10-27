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
    st.title("⚙️ Settings")

    # Agent selector
    agent_options = {
        'awaio_agent': 'Awaio Agent (autonomous, with SQL)',
        'awaio_gemini_agent': 'Gemini Model (Basic)',
        'awaio_chat_agent': 'OpenAI Model'
    }

    selected = st.selectbox(
        "Choose AI agent:",
        options=list(agent_options.keys()),
        format_func=lambda x: agent_options[x],
        index=0
    )
    st.session_state.selected_agent = selected

    st.divider()

    # Clear chat button
    if st.button("🗑️ Clear chat", use_container_width=True):
        st.session_state.messages = []
        st.rerun()

    st.divider()

    # Info section
    st.markdown("### 📊 About Awaio AI")
    st.markdown("""
    This chat agent analyses booking data from the Awaio system.

    **Database:**
    - 57 desks
    - 3 floors + Tillsammansytan
    - Booking history
    - User data

    **Ask me about:**
    - Booking trends
    - Resource utilisation
    - Popular desks
    - Weekday analysis
    - Recommendations
    """)

# Main chat interface
st.title("💬 Awaio AI Chat")
st.markdown(f"Chat with your booking data via **{agent_options[st.session_state.selected_agent]}**")

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if "timestamp" in message:
            st.caption(message["timestamp"])

# Chat input
if prompt := st.chat_input("Ask a question about the booking data..."):
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
        message_placeholder.markdown("🤔 Analysing data...")

        try:
            # Connect to MindsDB
            server = get_mindsdb_connection()

            if server is None:
                response = "❌ Could not connect to MindsDB. Check that the MindsDB container is running."
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

                    if any(word in prompt_lower for word in ['popular', 'most booked', 'best', 'desk']):
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
                        WHERE m.question = 'Here is data on desk popularity. Answer the user question: "{prompt.replace("'", "''")}" - Answer BRIEFLY (max 2 sentences) with concrete names and numbers.'
                        """

                    elif any(word in prompt_lower for word in ['weekday', 'day', 'weekdays']):
                        query = f"""
                        SELECT m.answer
                        FROM {st.session_state.selected_agent} m
                        JOIN (
                            SELECT
                                CASE EXTRACT(DOW FROM start_time)
                                    WHEN 0 THEN 'Sunday'
                                    WHEN 1 THEN 'Monday'
                                    WHEN 2 THEN 'Tuesday'
                                    WHEN 3 THEN 'Wednesday'
                                    WHEN 4 THEN 'Thursday'
                                    WHEN 5 THEN 'Friday'
                                    WHEN 6 THEN 'Saturday'
                                END as weekday,
                                COUNT(*) as bookings
                            FROM awaio_postgres.bookings
                            GROUP BY EXTRACT(DOW FROM start_time)
                            ORDER BY bookings DESC
                        ) data
                        WHERE m.question = 'Here is booking data per weekday. Answer: "{prompt.replace("'", "''")}" - Answer BRIEFLY (max 2 sentences).'
                        """

                    elif any(word in prompt_lower for word in ['total', 'how many', 'number of']):
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
                        WHERE m.question = 'Here are the overall statistics. Answer: "{prompt.replace("'", "''")}" - Answer BRIEFLY (max 2 sentences).'
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
                    response = "❌ No answer from the AI agent. Check that the model is trained and ready."

        except Exception as e:
            response = f"❌ An error occurred: {str(e)}"

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
    st.markdown("### 💡 Example questions:")

    col1, col2 = st.columns(2)

    with col1:
        if st.button("📊 Which weekday has the most bookings?", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Which weekday has the most bookings?",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()

        if st.button("🏢 Which desk is the most popular?", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Which desk is the most popular?",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()

    with col2:
        if st.button("📈 Give me a weekly report", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Write a short summary of this week's bookings and trends",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()

        if st.button("💡 Which resources are under-used?", use_container_width=True):
            st.session_state.messages.append({
                "role": "user",
                "content": "Which resources are under-used and what do you recommend?",
                "timestamp": datetime.now().strftime("%H:%M:%S")
            })
            st.rerun()
