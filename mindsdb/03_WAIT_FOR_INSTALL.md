# ⏳ Lightwood installeras just nu!

## Status
Lightwood-paketet (ML-engine för MindsDB) installeras i din MindsDB-container.

**Nuvarande steg:** Laddar ner och installerar:
- ✅ sktime (36.7 MB) - KLART
- ⏳ torch (102.1 MB) - PÅGÅR...
- ⏳ Diverse dependencies (statsforecast, optuna, xgboost, etc.)

## Beräknad tid
**2-5 minuter** beroende på internetuppkoppling.

## Vad händer?
```bash
docker exec awaio-mindsdb pip install lightwood
```

Lightwood är MindsDB:s standardbibliotek för machine learning och krävs för att skapa prediktionsmodeller.

## Efter installation
När installationen är klar (du ser "Successfully installed lightwood..."):

1. **Starta om MindsDB:**
   ```bash
   docker-compose restart mindsdb
   ```

2. **Testa att det fungerar:**
   Kör [03_first_prediction_model.sql](03_first_prediction_model.sql) i MindsDB Web UI

3. **Skapa din första ML-modell:**
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

## Kontrollera installationsstatus

Om du vill se exakt vad som händer:
```bash
docker logs -f awaio-mindsdb
```

Tryck Ctrl+C för att sluta följa loggarna.

## Om något går fel

**Timeout eller avbruten installation:**
```bash
# Försök igen
docker exec awaio-mindsdb pip install lightwood
```

**Minne slut:**
```bash
# Öka Docker memory limit i Docker Desktop → Settings → Resources
# Rekommenderat: minst 4GB RAM för MindsDB med ML
```

**Fortfarande problem:**
Se [INSTALL_ML_ENGINES.md](INSTALL_ML_ENGINES.md) för alternativa lösningar.

---

**Nästa:** När installationen är klar, fortsätt med [QUICKSTART.md](QUICKSTART.md) steg 4.
