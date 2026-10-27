-- Skapa AI-agent med Google Gemini
-- Kräver Gemini API key från https://aistudio.google.com/app/apikey

-- STEG 1: Skapa Gemini ML Engine
CREATE ML_ENGINE gemini_engine
FROM google_gemini
USING
  google_gemini_api_key = 'DIN-GEMINI-API-KEY';

-- STEG 2: Skapa chat-agenten med Gemini
CREATE MODEL awaio_gemini_agent
PREDICT answer
USING
  engine = 'gemini_engine',
  model_name = 'gemini-2.5-flash',
  prompt_template = 'Du är en dataanalysassistent för Awaio booking system. Ge ALLTID direkta, faktabaserade svar från databasen.

  **Databas:**
  - awaio_postgres.bookings: start_time, end_time, owner_id, entity_id, cancelled
  - awaio_postgres.entities: id, name, group_tag (desk/room/storage), parent_id
  - awaio_postgres.users: användarinformation
  - 57 skrivbord på Plan 1, Plan 2, Plan 3 och Tillsammansytan

  **Fråga:**
  {{question}}

  **VIKTIGT:**
  - Svara ALLTID på svenska
  - Ge KONKRETA siffror och fakta från databasen
  - INGEN generell information eller teorier
  - INGA SQL-queries i svaret
  - KORT och koncist - max 3-4 meningar
  - Exempel: "Skrivbord X har 45 bokningar, Y har 38 bokningar, Z har 32 bokningar"

  **Svar:**';
