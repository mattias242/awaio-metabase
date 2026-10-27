-- Steg 1: Anslut MindsDB till PostgreSQL
-- Kör denna SQL i MindsDB Web UI (http://localhost:47334)

CREATE DATABASE awaio_postgres
WITH ENGINE = 'postgres',
PARAMETERS = {
  "host": "postgres",
  "port": 5432,
  "database": "awaio_db",
  "user": "awaio_user",
  "password": "change_me"
};
