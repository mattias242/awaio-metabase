# Installera ML-Engines i MindsDB

## Problem
Open source MindsDB saknar ofta ML-engines som `lightwood` installerade by default.

## Lösning 1: Installera lightwood i befintlig container

```bash
# Gå in i MindsDB-containern
docker exec -it awaio-mindsdb bash

# Installera lightwood
pip install lightwood

# Starta om MindsDB (från host)
docker-compose restart mindsdb
```

## Lösning 2: Skapa egen Dockerfile med ML-engines

Skapa `Dockerfile.mindsdb`:

```dockerfile
FROM mindsdb/mindsdb:latest

# Installera ML-engines
RUN pip install --no-cache-dir \
    lightwood \
    statsforecast \
    neuralforecast

# Exponera portar
EXPOSE 47334 47335 47336

CMD ["python", "-m", "mindsdb"]
```

Uppdatera `docker-compose.yml`:

```yaml
mindsdb:
  build:
    context: .
    dockerfile: Dockerfile.mindsdb
  container_name: awaio-mindsdb
  # ... resten av konfigurationen
```

Bygg och starta:

```bash
docker-compose build mindsdb
docker-compose up -d mindsdb
```

## Lösning 3: Använd aggregeringsanalyser istället

Om du inte behöver avancerad ML, kan du använda PostgreSQL-aggregeringar direkt:

```sql
-- Genomsnittligt antal bokningar per veckodag (senaste 90 dagarna)
SELECT
  EXTRACT(DOW FROM start_time) as day_of_week,
  CASE EXTRACT(DOW FROM start_time)
    WHEN 0 THEN 'Söndag'
    WHEN 1 THEN 'Måndag'
    WHEN 2 THEN 'Tisdag'
    WHEN 3 THEN 'Onsdag'
    WHEN 4 THEN 'Torsdag'
    WHEN 5 THEN 'Fredag'
    WHEN 6 THEN 'Lördag'
  END as weekday,
  COUNT(*) as total_bookings,
  ROUND(COUNT(*)::numeric / 13, 1) as avg_per_week
FROM awaio_postgres.bookings
WHERE start_time >= NOW() - INTERVAL '90 days'
GROUP BY day_of_week
ORDER BY day_of_week
```

## Lösning 4: Använd Python för ML (utanför MindsDB)

Se `python_ml/` mappen för exempel på att använda scikit-learn, prophet, eller statsmodels direkt för predictions.

## Verifiera tillgängliga ML-engines

Kör i MindsDB:

```sql
SELECT * FROM information_schema.handlers WHERE type = 'ml'
```

Om listan är tom = inga ML-engines installerade.
