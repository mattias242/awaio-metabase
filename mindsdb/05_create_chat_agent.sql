-- Create an AI agent that can chat about booking data
-- Requires an OpenAI API key or another LLM integration

-- STEP 1: Create an LLM model for conversation
CREATE MODEL awaio_chat_agent
PREDICT answer
USING
  engine = 'openai',
  model_name = 'gpt-4',
  prompt_template = 'You are a helpful assistant that analyses booking data for Awaio.

  Database context:
  - The "bookings" table holds all bookings with start_time, end_time, owner_id, entity_id
  - The "entities" table holds bookable resources (desks, rooms, lockers) with name and group_tag
  - The "users" table holds user information

  The user asks: {{question}}

  Answer in English and be specific. If you need data, explain which SQL query is needed.';

-- ALTERNATIVE: Use an open model via Hugging Face
-- CREATE MODEL awaio_chat_agent
-- PREDICT answer
-- USING
--   engine = 'huggingface',
--   task = 'text-generation',
--   model_name = 'mistralai/Mistral-7B-Instruct-v0.2',
--   input_column = 'question',
--   max_new_tokens = 500;
