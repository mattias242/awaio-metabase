# Installing ML engines in MindsDB

## Problem
Open-source MindsDB often lacks ML engines such as `lightwood` by default.

## Solution 1: install lightwood in the existing container

```bash
# Open a shell in the MindsDB container
docker exec -it awaio-mindsdb bash

# Install lightwood
pip install lightwood

# Restart MindsDB (from the host)
docker-compose restart mindsdb
```

## Solution 2: create your own Dockerfile with ML engines

Create `Dockerfile.mindsdb`:

```dockerfile
FROM mindsdb/mindsdb:latest

# Install ML engines
RUN pip install --no-cache-dir \
    lightwood \
    statsforecast \
    neuralforecast

# Expose ports
EXPOSE 47334 47335 47336

CMD ["python", "-m", "mindsdb"]
```

Update `docker-compose.yml`:

```yaml
mindsdb:
  build:
    context: .
    dockerfile: Dockerfile.mindsdb
  container_name: awaio-mindsdb
  # ... the rest of the configuration
```

Build and start:

```bash
docker-compose build mindsdb
docker-compose up -d mindsdb
```

## Solution 3: use aggregate analyses instead

If you do not need advanced ML, you can use PostgreSQL aggregations directly:

```sql
-- Average number of bookings per weekday (last 90 days)
SELECT
  EXTRACT(DOW FROM start_time) as day_of_week,
  CASE EXTRACT(DOW FROM start_time)
    WHEN 0 THEN 'Sunday'
    WHEN 1 THEN 'Monday'
    WHEN 2 THEN 'Tuesday'
    WHEN 3 THEN 'Wednesday'
    WHEN 4 THEN 'Thursday'
    WHEN 5 THEN 'Friday'
    WHEN 6 THEN 'Saturday'
  END as weekday,
  COUNT(*) as total_bookings,
  ROUND(COUNT(*)::numeric / 13, 1) as avg_per_week
FROM awaio_postgres.bookings
WHERE start_time >= NOW() - INTERVAL '90 days'
GROUP BY day_of_week
ORDER BY day_of_week
```

## Solution 4: use Python for ML (outside MindsDB)

See the `python_ml/` folder for examples of using scikit-learn, prophet or statsmodels directly for predictions.

## Verify the available ML engines

Run in MindsDB:

```sql
SELECT * FROM information_schema.handlers WHERE type = 'ml'
```

If the list is empty, no ML engines are installed.
