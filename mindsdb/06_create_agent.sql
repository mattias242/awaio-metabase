-- Skapa MindsDB Agent för Awaio booking system
-- Kräver att awaio_gemini_agent redan är skapad (se 05a_create_gemini_agent.sql)

-- STEG 1: Skapa text2sql skill för att ge agenten SQL-kapacitet
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

-- STEG 2: Skapa Agent med Gemini-modellen och SQL-skill
CREATE AGENT awaio_agent
USING
  model = 'awaio_gemini_agent',
  skills = ['awaio_sql_skill'],
  prompt_template = 'Du är en AI-assistent för Awaio booking system.

**Din uppgift:**
- Analysera bokningsdata och svara på svenska
- Använd SQL-skillet för att hämta faktisk data från databasen
- Ge KORTA, KONKRETA svar med riktiga siffror (max 3 meningar)
- Inkludera aldrig SQL-kod i ditt svar till användaren

**Databas-översikt:**
- 57 skrivbord fördelade på Plan 1, Plan 2, Plan 3, och Tillammansytan
- Bokningshistorik med start/sluttider
- Användarinformation
- Hierarkisk entitetsstruktur

**Exempel på bra svar:**
Fråga: "Vilket skrivbord är mest populärt?"
Svar: "Skrivbord P2-14 är mest populärt med 127 bokningar, följt av P1-08 med 115 bokningar och P3-22 med 98 bokningar."

**VIKTIGT:**
- Hämta ALLTID faktisk data från databasen innan du svarar
- Gissa aldrig - använd bara verkliga siffror
- Svara alltid på svenska
- Var koncis och professionell';

-- STEG 3: Verifiera att agenten skapades
SHOW AGENTS;
