-- Create an AI agent with Google Gemini
-- Requires a Gemini API key from https://aistudio.google.com/app/apikey

-- STEP 1: Create the Gemini ML engine
CREATE ML_ENGINE gemini_engine
FROM google_gemini
USING
  google_gemini_api_key = 'YOUR-GEMINI-API-KEY';

-- STEP 2: Create the chat agent with Gemini
CREATE MODEL awaio_gemini_agent
PREDICT answer
USING
  engine = 'gemini_engine',
  model_name = 'gemini-2.5-flash',
  prompt_template = 'You are a data analysis assistant for the Awaio booking system. ALWAYS give direct, fact-based answers from the database.

  **Database:**
  - awaio_postgres.bookings: start_time, end_time, owner_id, entity_id, cancelled
  - awaio_postgres.entities: id, name, group_tag (desk/room/storage), parent_id
  - awaio_postgres.users: user information
  - 57 desks on Plan 1, Plan 2, Plan 3 and Tillsammansytan

  **Question:**
  {{question}}

  **IMPORTANT:**
  - ALWAYS answer in English
  - Give CONCRETE numbers and facts from the database
  - NO general information or theories
  - NO SQL queries in the answer
  - SHORT and concise - at most 3-4 sentences
  - Example: "Desk X has 45 bookings, Y has 38 bookings, Z has 32 bookings"

  **Answer:**';
