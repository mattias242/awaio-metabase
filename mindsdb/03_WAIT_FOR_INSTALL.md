# ⏳ Lightwood is being installed!

## Status
The Lightwood package (ML engine for MindsDB) is being installed in your MindsDB container.

**Current step:** downloading and installing:
- ✅ sktime (36.7 MB) - DONE
- ⏳ torch (102.1 MB) - IN PROGRESS...
- ⏳ Various dependencies (statsforecast, optuna, xgboost, etc.)

## Estimated time
**2-5 minutes** depending on your internet connection.

## What is happening?
```bash
docker exec awaio-mindsdb pip install lightwood
```

Lightwood is MindsDB's standard machine-learning library and is required to create prediction models.

## After the installation
When the installation is finished (you see "Successfully installed lightwood..."):

1. **Restart MindsDB:**
   ```bash
   docker-compose restart mindsdb
   ```

2. **Test that it works:**
   Run [03_first_prediction_model.sql](03_first_prediction_model.sql) in the MindsDB Web UI

3. **Create your first ML model:**
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
   ```

## Check the installation status

If you want to see exactly what is happening:
```bash
docker logs -f awaio-mindsdb
```

Press Ctrl+C to stop following the logs.

## If something goes wrong

**Timeout or interrupted installation:**
```bash
# Try again
docker exec awaio-mindsdb pip install lightwood
```

**Out of memory:**
```bash
# Increase the Docker memory limit in Docker Desktop → Settings → Resources
# Recommended: at least 4GB RAM for MindsDB with ML
```

**Still having problems:**
See [INSTALL_ML_ENGINES.md](INSTALL_ML_ENGINES.md) for alternative solutions.

---

**Next:** when the installation is finished, continue with step 4 of [QUICKSTART.md](QUICKSTART.md).
