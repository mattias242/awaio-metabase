# MindsDB SQL Syntax Guide

## Key differences from standard SQL

MindsDB uses **JOIN syntax** to get predictions, not a plain SELECT.

## 1. Create a model

```sql
CREATE MODEL project_name.model_name
FROM database_name
  (SELECT column1, column2, target_column
   FROM table_name
   WHERE conditions)
PREDICT target_column
[ORDER BY time_column]  -- For time series
[WINDOW int]            -- Number of rows to look back
[HORIZON int]           -- Number of future predictions
[USING engine = 'lightwood'];
```

### Example: simple prediction

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

### Example: time series with WINDOW and HORIZON

```sql
CREATE MODEL house_sales_predictor
FROM files
  (SELECT * FROM house_sales)
PREDICT MA
ORDER BY saledate  -- Time series column
WINDOW 8           -- Use the 8 previous rows
HORIZON 4          -- Predict 4 future rows
```

## 2. Getting predictions (IMPORTANT!)

### ❌ DOES NOT WORK:
```sql
-- This does NOT work in MindsDB!
SELECT * FROM booking_forecast
WHERE booking_date > CURRENT_DATE
```

### ✅ CORRECT SYNTAX - use JOIN:

**A. Predictions from new data (JOIN with a data table):**
```sql
SELECT
  t.booking_date,
  t.day_of_week,
  m.booking_count AS predicted_bookings
FROM awaio_postgres.bookings AS t
JOIN booking_forecast AS m
LIMIT 14
```

**B. Future predictions (time series):**
```sql
SELECT
  m.booking_date AS date,
  m.booking_count AS forecast
FROM booking_forecast AS m
JOIN awaio_postgres.bookings AS t
WHERE t.booking_date > LATEST  -- Special MindsDB keyword for time series
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

## 3. USING clause parameters

### Common engines:
- `lightwood` - default ML engine (installed now!)
- `huggingface` - for NLP models
- `openai_engine` - for LLM models

### Parameters:
```sql
USING
  engine = 'lightwood',
  tag = 'my_model_v1',
  stop_train_in_x_seconds = 60
```

## 4. Time-series-specific features

### ORDER BY
Specifies the column that represents time/sequence:
```sql
ORDER BY saledate
```

### WINDOW
Number of previous rows to use for the prediction:
```sql
WINDOW 8  -- Use the last 8 rows
```

### HORIZON
Number of future predictions:
```sql
HORIZON 4  -- Predict 4 steps ahead
```

### LATEST keyword
Used in WHERE to get future predictions:
```sql
WHERE t.saledate > LATEST
```

## 5. Managing models

### Show all models:
```sql
SHOW MODELS;
```

### See the model status:
```sql
DESCRIBE model_name;
```

### Delete a model:
```sql
DROP MODEL model_name;
```

### Retrain a model:
```sql
RETRAIN model_name;
```

## 6. Limitations

- ❌ CASE expressions do NOT work in SELECT from models
- ❌ Complex aggregations in SELECT do NOT work
- ✅ Use JOIN syntax for all predictions
- ✅ Do transformations in the training data (the CREATE MODEL FROM clause)

## 7. Best practices

1. **Prepare the data in CREATE MODEL:**
   - Do all CASE, aggregations and transformations in the FROM clause
   - Keep prediction queries simple (just a JOIN)

2. **Time series models:**
   - Always use ORDER BY for time series
   - Set WINDOW based on seasonal patterns
   - HORIZON = number of steps you want to predict ahead

3. **Testing:**
   - Always check `DESCRIBE model_name` for the status
   - Wait until STATUS = 'complete'
   - Test with LIMIT first

4. **Performance:**
   - Filter in the JOIN WHERE clause
   - Use LIMIT for large datasets
   - Less training data = faster training

## 8. Troubleshooting

### "Unknown select target"
- **Problem**: using CASE or a complex SELECT from a model
- **Solution**: move the logic to the CREATE MODEL FROM clause

### "No module named 'lightwood'"
- **Problem**: the ML engine is not installed
- **Solution**: `docker exec awaio-mindsdb pip install lightwood`

### "Column not found"
- **Problem**: the column names differ between the data and the model
- **Solution**: check the column names in DESCRIBE model_name

### The model does not train
- **Problem**: too little data or wrong data types
- **Solution**: at least 50-100 rows of data are recommended
