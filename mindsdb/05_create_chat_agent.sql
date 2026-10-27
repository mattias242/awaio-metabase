-- Skapa en AI-agent som kan chatta om bokningsdata
-- Kräver OpenAI API key eller annan LLM-integration

-- STEG 1: Skapa LLM-modell för konversation
CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'openai',
  model_name = 'gpt-4',
  prompt_template = 'Du är en hjälpsam assistent som analyserar bokningsdata för Awaio.

  Kontext om databasen:
  - Tabellen "bookings" innehåller alla bokningar med start_time, end_time, owner_id, entity_id
  - Tabellen "entities" innehåller bokningsbara resurser (skrivbord, rum, skåp) med name och group_tag
  - Tabellen "users" innehåller användarinformation

  Användaren frågar: {{question}}

  Svara på svenska och var konkret. Om du behöver data, förklara vilken SQL-query som behövs.';

-- ALTERNATIV: Använd öppen modell via Hugging Face
-- CREATE MODEL awaio_chat_agent
-- PREDICT answer
-- USING
--   engine = 'huggingface',
--   task = 'text-generation',
--   model_name = 'mistralai/Mistral-7B-Instruct-v0.2',
--   input_column = 'question',
--   max_new_tokens = 500;
