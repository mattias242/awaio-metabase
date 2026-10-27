# Metabase Metrics Setup Guide

Detta dokument beskriver hur du skapar återanvändbara Metrics i Metabase för Awaio-projektet.

## Vad är Metrics?

Metrics är förkonfigurerade aggregeringar som kan återanvändas över flera frågor och dashboards. De säkerställer konsekventa beräkningar och förenklar analys för icke-tekniska användare.

## Fördefinierade Metrics för Awaio

Följande Metrics täcker de vanligaste beräkningarna för bokningsanalys.

---

## 1. Antal bokningar

**Namn:** `Antal bokningar`
**Tabell:** `bookings`
**Typ:** Count of rows
**Filter:** Ingen (räknar alla bokningar)

### Skapa i Metabase:
1. Gå till **Settings** → **Admin** → **Table Metadata**
2. Välj databas: `awaio_db`
3. Hitta tabellen: `bookings`
4. Klicka på **+ Add a Metric**
5. Fyll i:
   - **Name:** `Antal bokningar`
   - **Description:** `Totalt antal bokningar i systemet`
   - **Definition:** Välj `Count of rows`
6. Spara

### Användningsexempel:
```sql
-- I Query Builder:
SELECT "Antal bokningar" FROM bookings
GROUP BY entity_id

-- Resultat: Antal bokningar per entity
```

---

## 2. Genomsnittlig bokningstid (timmar)

**Namn:** `Genomsnittlig bokningstid (timmar)`
**Tabell:** `bookings`
**Typ:** Custom expression
**Formel:** `AVG([end_time] - [start_time]) / 3600`

### Skapa i Metabase:
1. Gå till **Settings** → **Admin** → **Table Metadata**
2. Välj databas: `awaio_db`
3. Hitta tabellen: `bookings`
4. Klicka på **+ Add a Metric**
5. Fyll i:
   - **Name:** `Genomsnittlig bokningstid (timmar)`
   - **Description:** `Genomsnittlig längd på bokningar i timmar (end_time - start_time)`
   - **Definition:** Välj `Custom Expression`
   - **Expression:**
     ```
     Average([End Time] - [Start Time]) / interval(1, 'hour')
     ```
     *OBS: Metabase GUI kan ha olika syntax, testa också:*
     ```
     AVG(([End Time] - [Start Time]) / 3600000000000)
     ```
     *(PostgreSQL interval till sekunder, sedan till timmar)*

### Alternativ SQL för Native Query:
Om Custom Expression är komplicerad i GUI, använd Native Query:
```sql
SELECT
    entity_id,
    AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600) as genomsnittlig_bokningstid_timmar
FROM bookings
GROUP BY entity_id
```

### Användningsexempel:
- Jämföra genomsnittlig bokningstid mellan rum och skrivbord
- Identifiera resurser med onormalt långa/korta bokningar
- Trend över tid (ökar/minskar medeltiden?)

---

## 3. Total bokad tid (timmar)

**Namn:** `Total bokad tid (timmar)`
**Tabell:** `bookings`
**Typ:** Custom expression
**Formel:** `SUM([end_time] - [start_time]) / 3600`

### Skapa i Metabase:
1. Gå till **Settings** → **Admin** → **Table Metadata**
2. Välj databas: `awaio_db`
3. Hitta tabellen: `bookings`
4. Klicka på **+ Add a Metric**
5. Fyll i:
   - **Name:** `Total bokad tid (timmar)`
   - **Description:** `Total summerad tid för alla bokningar i timmar`
   - **Definition:** Välj `Custom Expression`
   - **Expression:**
     ```
     Sum([End Time] - [Start Time]) / interval(1, 'hour')
     ```

### Alternativ SQL för Native Query:
```sql
SELECT
    entity_id,
    SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600) as total_bokad_tid_timmar
FROM bookings
GROUP BY entity_id
```

### Användningsexempel:
- Total utnyttjandetid per rum
- Identifiera mest använda resurser (totalt)
- Kapacitetsplanering (hur många timmar bokas per vecka/månad?)

---

## 4. Unika användare

**Namn:** `Unika användare`
**Tabell:** `bookings`
**Typ:** Count of distinct values
**Fält:** `owner_id`

### Skapa i Metabase:
1. Gå till **Settings** → **Admin** → **Table Metadata**
2. Välj databas: `awaio_db`
3. Hitta tabellen: `bookings`
4. Klicka på **+ Add a Metric**
5. Fyll i:
   - **Name:** `Unika användare`
   - **Description:** `Antal unika användare som gjort bokningar`
   - **Definition:** Välj `Distinct values of...`
   - **Column:** Välj `Owner ID`
6. Spara

### Användningsexempel:
```sql
-- I Query Builder:
SELECT "Unika användare" FROM bookings
GROUP BY entity_id

-- Resultat: Antal unika användare per entity
```

### Användningsexempel:
- Identifiera rum med många vs. få unika användare
- Popularitet över tid (ökar antalet användare?)
- Jämföra skrivbord vs. rum (vilka har bredare användarbas?)

---

## Tekniska detaljer: Tidsberäkningar i PostgreSQL

### PostgreSQL INTERVAL aritmetik:
```sql
-- Skillnad mellan timestamps ger INTERVAL
end_time - start_time  -- Resultat: '4 hours 30 minutes'

-- Konvertera INTERVAL till sekunder
EXTRACT(EPOCH FROM (end_time - start_time))  -- Resultat: 16200 (sekunder)

-- Konvertera sekunder till timmar
EXTRACT(EPOCH FROM (end_time - start_time)) / 3600  -- Resultat: 4.5 (timmar)
```

### Metabase Custom Expression syntax:
Metabase använder sin egen syntax för tidsberäkningar. Om ovanstående expressions inte fungerar, testa:

**För timmar:**
```
([End Time] - [Start Time]) / 3600000000000
```
*(Metabase kan representera interval som nanosekunder internt)*

**Eller använd Native SQL query istället:**
```sql
SELECT
    AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600)
FROM bookings
```

---

## Kombinera Metrics med Segments

### Exempel: Skapa Segment för "Långa bokningar"

1. Gå till **Settings** → **Admin** → **Table Metadata**
2. Välj tabellen: `bookings`
3. Klicka på **+ Add a Segment**
4. Namn: `Långa bokningar (>4h)`
5. Filter:
   ```
   [Total bokad tid (timmar)] > 4
   ```
   *Eller:*
   ```
   ([End Time] - [Start Time]) > interval(4, 'hour')
   ```

### Kombinera Segment + Metric:
- **Segment:** "Långa bokningar (>4h)"
- **Metric:** "Antal bokningar"
- **Resultat:** Antal bokningar som är längre än 4 timmar

---

## Använda Metrics i SQL Queries

Du kan **inte** direkt referera till Metrics i Native SQL queries. Men Metrics är användbara när du använder **Query Builder** (GUI).

### Strategi:
1. **Skapa Metrics för grundläggande aggregeringar** (som ovan)
2. **Använd Query Builder för enkla frågor** → Välj Metrics från dropdown
3. **Använd Native SQL för komplexa analyser** → Skriv formeln direkt (som i dina befintliga queries)

### Exempel: Befintlig query med Metric-logik

**Befintlig SQL (metabase/04_top10_populäraste_rum_med_snitttid.sql):**
```sql
SELECT
    e.name AS rum,
    COUNT(b.id) AS antal_bokningar,  -- Detta är Metric: "Antal bokningar"
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS snitt_timmar  -- Detta är Metric: "Genomsnittlig bokningstid"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'room'
GROUP BY e.id, e.name
ORDER BY antal_bokningar DESC
LIMIT 10;
```

**Med Query Builder + Metrics:**
1. Välj tabell: `bookings`
2. Join med: `entities` (via `entity_id`)
3. Filter: `group_tag = 'room'`
4. Summarize:
   - Metric: "Antal bokningar"
   - Metric: "Genomsnittlig bokningstid (timmar)"
5. Group by: `entities.name`
6. Sort: "Antal bokningar" descending
7. Limit: 10

---

## Verifiering av Metrics

### Test 1: Jämför Metric med direkt SQL

**SQL Query:**
```sql
SELECT COUNT(*) FROM bookings;
```

**Query Builder:**
1. Välj tabell: `bookings`
2. Summarize: "Antal bokningar"
3. Resultatet ska matcha SQL-frågan

### Test 2: Kontrollera genomsnittlig bokningstid

**SQL Query:**
```sql
SELECT AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600)
FROM bookings;
```

**Query Builder:**
1. Välj tabell: `bookings`
2. Summarize: "Genomsnittlig bokningstid (timmar)"
3. Resultatet ska matcha (inom avrundning)

---

## Felsökning

### Problem: "Custom Expression" fungerar inte

**Lösning:** Metabase GUI kan ha begränsningar för komplexa tidsberäkningar. Använd Native SQL istället:

```sql
-- Skapa en SQL "Saved Question" istället för Metric
SELECT
    'Genomsnittlig bokningstid' AS metric_namn,
    ROUND(AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600)::numeric, 2) AS värde
FROM bookings;
```

### Problem: Metric visar fel värde

**Kontrollera:**
1. **Tidszon:** Är `end_time` och `start_time` i rätt tidszon?
2. **Enhet:** Är interval i sekunder, millisekunder eller nanosekunder?
3. **NULL-värden:** Filtrera bort `WHERE end_time IS NOT NULL`

### Problem: Kan inte hitta "Add a Metric"

**Lösning:**
- Metrics kräver Admin-behörighet
- Kontrollera att du är inloggad som Admin-användare
- Om knappen saknas, kolla Metabase-versionen (gamla versioner har annan UI)

---

## Nästa steg

### Fler användbara Metrics:
1. **"Antal bokningar (rum)"** - COUNT med filter `group_tag = 'room'`
2. **"Antal bokningar (skrivbord)"** - COUNT med filter `group_tag = 'desk'`
3. **"Medel kapacitet per bokning"** - AVG(entity.capacity_normal)
4. **"Peak-timmar (9-17)"** - SUM med filter på EXTRACT(HOUR FROM start_time)

### Segments att skapa:
1. **"Långa bokningar (>4h)"**
2. **"Korta bokningar (<1h)"**
3. **"Kontorstid (9-17)"**
4. **"Helgbokningar"**
5. **"Senaste 30 dagarna"**

Dessa kan kombineras med Metrics för kraftfull ad-hoc-analys utan SQL-kunskap!

---

## Referenser

- [Metabase Metrics Documentation](https://www.metabase.com/docs/latest/data-modeling/metrics)
- [PostgreSQL Interval Arithmetic](https://www.postgresql.org/docs/current/functions-datetime.html)
- Projekt: `/metabase/*.sql` - Befintliga SQL queries som kan dra nytta av Metrics
