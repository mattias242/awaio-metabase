# MindsDB Quickstart - Awaio Predictions

## 🚀 Snabbstart (5 minuter)

### 1. Öppna MindsDB Web UI
Öppna i din webbläsare: **http://localhost:47334**

### 2. Anslut till PostgreSQL
Kopiera och kör [01_connect_postgres.sql](01_connect_postgres.sql) i SQL Editor:

```sql
CREATE DATABASE awaio_postgres
WITH ENGINE = 'postgres',
PARAMETERS = {
  "host": "postgres",
  "port": 5432,
  "database": "awaio_db",
  "user": "awaio_user",
  "password": "change_me"
};
```

**Förväntat resultat:** "Query successfully completed"

### 3. Testa anslutningen

**VIKTIGT:** MindsDB Web UI kör bara EN query åt gången!

Kör varje fil separat:

**A. Visa databaser** - Kör [02a_show_databases.sql](02a_show_databases.sql):
```sql
SHOW DATABASES
```
**Du ska se:** `awaio_postgres` i listan

**B. Testa läsa bokningar** - Kör [02b_test_bookings.sql](02b_test_bookings.sql):
```sql
SELECT * FROM awaio_postgres.bookings LIMIT 10
```
**Du ska se:** 10 bokningar från din databas

**C. Visa tabeller** - Kör [02c_show_tables.sql](02c_show_tables.sql):
```sql
SHOW TABLES FROM awaio_postgres
```
**Du ska se:** bookings, entities, users, communities, etc.

**D. Se statistik** - Kör [02d_booking_stats.sql](02d_booking_stats.sql):
```sql
SELECT
  COUNT(*) as total_bookings,
  COUNT(DISTINCT owner_id) as unique_users,
  COUNT(DISTINCT entity_id) as unique_entities,
  MIN(start_time) as earliest_booking,
  MAX(start_time) as latest_booking
FROM awaio_postgres.bookings
```

### 4. Skapa din första ML-modell
Kör [03_first_prediction_model.sql](03_first_prediction_model.sql):

```sql
CREATE MODEL booking_forecast
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('day', start_time) as booking_date,
     EXTRACT(DOW FROM start_time) as day_of_week,
     COUNT(*) as booking_count
   FROM bookings
   WHERE start_time >= NOW() - INTERVAL '90 days'
     AND start_time < NOW()
   GROUP BY booking_date, day_of_week
   ORDER BY booking_date)
PREDICT booking_count
ORDER BY booking_date
USING
  engine = 'statsforecast',
  horizon = 14;
```

**OBS:** Detta tar 2-5 minuter! Vänta tills det är klart.

### 5. Kontrollera träningsstatus
```sql
DESCRIBE booking_forecast;
```

**Leta efter:** `STATUS: complete` eller `STATUS: generating`

### 6. Använd predictions!
När modellen är klar, kör [04_use_predictions.sql](04_use_predictions.sql):

```sql
SELECT
  booking_date,
  CASE day_of_week
    WHEN 0 THEN 'Söndag'
    WHEN 1 THEN 'Måndag'
    WHEN 2 THEN 'Tisdag'
    WHEN 3 THEN 'Onsdag'
    WHEN 4 THEN 'Torsdag'
    WHEN 5 THEN 'Fredag'
    WHEN 6 THEN 'Lördag'
  END as weekday,
  booking_count as predicted_bookings
FROM booking_forecast
WHERE booking_date > CURRENT_DATE
ORDER BY booking_date
LIMIT 14;
```

**Resultat:** Förutsägelser för bokningar de nästa 14 dagarna! 🎉

---

## 📊 Fler Avancerade Modeller

När du är klar med grunderna, prova dessa:

### Kapacitetsprediktion per timme
```sql
CREATE MODEL hourly_capacity
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('hour', b.start_time) as time_slot,
     EXTRACT(DOW FROM b.start_time) as day_of_week,
     EXTRACT(HOUR FROM b.start_time) as hour_of_day,
     COUNT(DISTINCT b.entity_id) as desks_in_use
   FROM bookings b
   JOIN entities e ON b.entity_id = e.id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '60 days'
   GROUP BY time_slot, day_of_week, hour_of_day)
PREDICT desks_in_use
USING engine = 'lightwood';
```

### Användning:
```sql
-- Kapacitet imorgon
SELECT
  time_slot,
  hour_of_day,
  desks_in_use as predicted_desks,
  ROUND((desks_in_use::numeric / 57 * 100), 1) as utilization_pct
FROM hourly_capacity
WHERE time_slot::date = CURRENT_DATE + INTERVAL '1 day'
ORDER BY hour_of_day;
```

### Populära skrivbord nästa vecka
```sql
CREATE MODEL desk_popularity
FROM awaio_postgres
  (SELECT
     e.id as desk_id,
     e.name as desk_name,
     DATE_TRUNC('week', b.start_time) as week_start,
     COUNT(b.id) as weekly_bookings,
     COUNT(DISTINCT b.owner_id) as unique_users
   FROM entities e
   JOIN bookings b ON e.id = b.entity_id
   WHERE e.group_tag = 'desk'
     AND b.start_time >= NOW() - INTERVAL '90 days'
   GROUP BY e.id, e.name, week_start)
PREDICT weekly_bookings
USING engine = 'lightwood';
```

### Användning:
```sql
-- Top 10 nästa vecka
SELECT
  desk_name,
  weekly_bookings as predicted_bookings
FROM desk_popularity
WHERE week_start = DATE_TRUNC('week', CURRENT_DATE + INTERVAL '7 days')
ORDER BY predicted_bookings DESC
LIMIT 10;
```

---

## 🔧 Troubleshooting

### "Connection failed"
- Kontrollera att PostgreSQL körs: `docker-compose ps postgres`
- Verifiera att båda containers är på samma nätverk

### "Model training failed"
- Kontrollera att du har tillräckligt med data (minst 30 dagar rekommenderas)
- Se detaljer: `DESCRIBE booking_forecast;`

### Modellen tar för lång tid
- Första träningen kan ta 2-10 minuter beroende på datamängd
- Prova med mindre dataset genom att öka INTERVAL-filtret

### "Table not found"
- Dubbelkolla att `awaio_postgres` är prefix: `awaio_postgres.bookings`
- Lista tabeller: `SHOW TABLES FROM awaio_postgres;`

---

## 📚 Nästa Steg

1. ✅ Skapa fler modeller (se README.md)
2. ✅ Integrera predictions i Metabase
3. ✅ Sätt upp automatisk retraining
4. ✅ Exportera predictions till PostgreSQL för visualisering

Se [README.md](README.md) för fullständig dokumentation och alla tillgängliga modeller.
