-- Create a MindsDB agent for the Awaio booking system
-- Requires awaio_gemini_agent to exist already (see 05a_create_gemini_agent.sql)

-- STEP 1: Create a text2sql skill to give the agent SQL capability
CREATE SKILL awaio_sql_skill
USING
  type = 'text2sql',
  database = 'awaio_postgres',
  tables = ['bookings', 'entities', 'users', 'communities', 'calendar_events'],
  description = 'Awaio booking system database containing:
  - bookings: All reservations with start_time, end_time, owner_id, entity_id, cancelled
  - entities: Bookable resources (57 desks, rooms, lockers) with hierarchical structure via parent_id
    * group_tag values: desk, room, storage
    * 4-level hierarchy: Building -> Floors (Plan 1-3) -> Areas -> Desks/Rooms/Lockers
  - users: User information including email and display_name
  - communities: Organizational groups
  - calendar_events: Calendar integration data

  Common queries:
  - Desk popularity: COUNT bookings per entity WHERE group_tag=desk
  - Weekday analysis: GROUP BY EXTRACT(DOW FROM start_time)
  - Availability: JOIN entities with bookings to find unused resources
  - User statistics: COUNT bookings per owner_id';

-- STEP 2: Create the agent with the Gemini model and the SQL skill
CREATE AGENT awaio_agent
USING
  model = 'awaio_gemini_agent',
  skills = ['awaio_sql_skill'],
  prompt_template = 'You are an AI assistant for the Awaio booking system.

**Your task:**
- Analyse booking data and answer in English
- Use the SQL skill to fetch actual data from the database
- Give SHORT, CONCRETE answers with real numbers (at most 3 sentences)
- Never include SQL code in your answer to the user

**Database overview:**
- 57 desks spread over Plan 1, Plan 2, Plan 3 and Tillsammansytan
- Booking history with start/end times
- User information
- Hierarchical entity structure

**Example of a good answer:**
Question: "Which desk is the most popular?"
Answer: "Desk P2-14 is the most popular with 127 bookings, followed by P1-08 with 115 bookings and P3-22 with 98 bookings."

**IMPORTANT:**
- ALWAYS fetch actual data from the database before answering
- Never guess - use only real numbers
- Always answer in English
- Be concise and professional';

-- STEP 3: Verify that the agent was created
SHOW AGENTS;
