# MindsDB SQL Syntax Guide

## Viktiga Skillnader mot Standard SQL

MindsDB använder **JOIN-syntax** för att få predictions, inte vanliga SELECT.

## 1. Skapa en Modell

```sql
CREATE MODEL project_name.model_name
FROM database_name
  (SELECT column1, column2, target_column
   FROM table_name
   WHERE conditions)
PREDICT target_column
[ORDER BY time_column]  -- För tidsserier
[WINDOW int]            -- Antal rader att titta tillbaka på
[HORIZON int]           -- Antal framtida predictions
[USING engine = 'lightwood'];
```

### Exempel: Enkel Prediction

```sql
CREATE MODEL booking_forecast
FROM awaio_postgres
  (SELECT
     DATE_TRUNC('day', start_time) as booking_date,
     EXTRACT(DOW FROM start_time) as day_of_week,
     COUNT(*) as booking_count
   FROM bookings
   WHERE start_time >= NOW() - INTERVAL '90 days'
   GROUP BY booking_date, day_of_week)
PREDICT booking_count
```

### Exempel: Tidsserie med WINDOW och HORIZON

```sql
CREATE MODEL house_sales_predictor
FROM files
  (SELECT * FROM house_sales)
PREDICT MA
ORDER BY saledate  -- Tidsserie-kolumn
WINDOW 8           -- Använd 8 tidigare rader
HORIZON 4          -- Predicera 4 framtida rader
```

## 2. Få Predictions (VIKTIGT!)

### ❌ FUNGERAR INTE:
```sql
-- Detta fungerar INTE i MindsDB!
SELECT * FROM booking_forecast
WHERE booking_date > CURRENT_DATE
```

### ✅ RÄTT SYNTAX - Använd JOIN:

**A. Predictions från ny data (JOIN med data table):**
```sql
SELECT
  t.booking_date,
  t.day_of_week,
  m.booking_count AS predicted_bookings
FROM awaio_postgres.bookings AS t
JOIN booking_forecast AS m
LIMIT 14
```

**B. Framtida predictions (time series):**
```sql
SELECT
  m.booking_date AS date,
  m.booking_count AS forecast
FROM booking_forecast AS m
JOIN awaio_postgres.bookings AS t
WHERE t.booking_date > LATEST  -- Speciellt MindsDB keyword för tidsserier
LIMIT 14
```

**C. Filtered predictions:**
```sql
SELECT
  t.number_of_rooms,
  m.rental_price AS predicted_price,
  t.rental_price AS actual_price
FROM example_db.home_rentals AS t
JOIN mindsdb.home_rentals_model AS m
WHERE t.number_of_rooms > 2
```

## 3. USING Clause Parameters

### Vanliga Engines:
- `lightwood` - Default ML engine (installerat nu!)
- `huggingface` - För NLP-modeller
- `openai_engine` - För LLM-modeller

### Parametrar:
```sql
USING
  engine = 'lightwood',
  tag = 'my_model_v1',
  stop_train_in_x_seconds = 60
```

## 4. Tidsserie-Specifika Features

### ORDER BY
Anger kolumn som representerar tid/sekvens:
```sql
ORDER BY saledate
```

### WINDOW
Antal tidigare rader att använda för prediction:
```sql
WINDOW 8  -- Använd senaste 8 raderna
```

### HORIZON
Antal framtida predictions:
```sql
HORIZON 4  -- Predicera 4 steg framåt
```

### LATEST Keyword
Används i WHERE för att få framtida predictions:
```sql
WHERE t.saledate > LATEST
```

## 5. Hantera Modeller

### Visa alla modeller:
```sql
SHOW MODELS;
```

### Se modellstatus:
```sql
DESCRIBE model_name;
```

### Ta bort modell:
```sql
DROP MODEL model_name;
```

### Retrain modell:
```sql
RETRAIN model_name;
```

## 6. Begränsningar

- ❌ CASE-uttryck fungerar INTE i SELECT från modeller
- ❌ Komplexa aggregeringar i SELECT fungerar INTE
- ✅ Använd JOIN-syntax för alla predictions
- ✅ Gör transformationer i träningsdata (CREATE MODEL FROM clause)

## 7. Best Practices

1. **Förbered data i CREATE MODEL:**
   - Gör alla CASE, aggregeringar, och transformationer i FROM-clause
   - Håll prediction queries enkla (bara JOIN)

2. **Tidsserie-modeller:**
   - Använd alltid ORDER BY för tidsserier
   - Sätt WINDOW baserat på säsongsmönster
   - HORIZON = antal steg du vill predicera framåt

3. **Testing:**
   - Kolla alltid `DESCRIBE model_name` för status
   - Vänta tills STATUS = 'complete'
   - Testa med LIMIT först

4. **Performance:**
   - Filtrera i JOIN WHERE-clause
   - Använd LIMIT för stora datasets
   - Mindre träningsdata = snabbare training

## 8. Troubleshooting

### "Unknown select target"
- **Problem**: Använder CASE eller komplex SELECT från modell
- **Lösning**: Flytta logiken till CREATE MODEL FROM clause

### "No module named 'lightwood'"
- **Problem**: ML-engine inte installerad
- **Lösning**: `docker exec awaio-mindsdb pip install lightwood`

### "Column not found"
- **Problem**: Kolumnnamn stämmer inte mellan data och modell
- **Lösning**: Kontrollera kolumnnamn i DESCRIBE model_name

### Modellen tränar inte
- **Problem**: För lite data eller fel datatyper
- **Lösning**: Minst 50-100 rader data rekommenderas
