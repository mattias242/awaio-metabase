# Guide: Skapa Grouped Bar Chart i Metabase

## Översikt

Denna guide visar hur du skapar ett stapeldiagram med flera serier (grouped bar chart) i Metabase för att jämföra bokningar mellan olika perioder.

## Exempel: Veckodag-jämförelse (fråga 09)

### Steg 1: Kör SQL-frågan

1. Öppna Metabase: http://localhost:3000
2. Klicka **"New"** → **"SQL query"**
3. Välj database: **"awaio_db"**
4. Kopiera innehållet från `09_veckodag_jamforelse_4veckor.sql`
5. Klicka **"Run"**

Du bör se data som:
```
Veckodag | Senaste 4 veckorna | Föregående 4 veckor | Förändring %
---------|--------------------|--------------------|-------------
1-Måndag |        189         |        273         |    -30.8
2-Tisdag |        229         |        322         |    -28.9
...
```

### Steg 2: Välj visualisering

1. Klicka på **"Visualization"**-knappen (bredvid Run)
2. Välj **"Bar"** (stapeldiagram)

### Steg 3: Konfigurera diagrammet

I visualiseringsinställningarna:

#### Data-flik:
- **X-axis**: `Veckodag`
- **Y-axis**:
  - ✅ `Senaste 4 veckorna`
  - ✅ `Föregående 4 veckor`
  - ❌ `Förändring %` (valfritt att ta med)

#### Display-flik:
- **Chart type**: Column chart (vertikala staplar)
- **Stacking**: **"None"** eller **"Side by side"** (viktigt!)
  - **INTE** "Stacked" - då läggs serierna ovanpå varandra
- **Show values on data points**: Valfritt (kan bli plottrigt)

#### Formatting-flik:
- **Colors**:
  - Serie 1 (Senaste 4 veckorna): Blå eller grön
  - Serie 2 (Föregående 4 veckor): Grå eller orange
- **Legend**: Visa legend för att förklara serierna

#### Axes-flik:
- **Y-axis label**: "Antal bokningar"
- **X-axis label**: "Veckodag" (eller lämna tom)
- **Y-axis scale**: Auto (eller manuell om önskat)

### Steg 4: Spara frågan

1. Klicka **"Save"**
2. Namn: "Veckodag-jämförelse (4 veckor)"
3. Description: "Jämför bokningar per veckodag mellan senaste 4 veckorna och tidigare 4 veckor"
4. Collection: Välj eller skapa "Awaio Analytics"

### Steg 5: Lägg till i Dashboard

1. Gå till din dashboard eller skapa ny
2. Klicka **"Add a question"**
3. Välj "Veckodag-jämförelse (4 veckor)"
4. Justera storlek (rekommenderat: full width eller halv)
5. Klicka **"Save"**

## Resultat

Du får ett stapeldiagram som visar:
- **X-axeln**: Veckodagar (Måndag-Söndag)
- **Y-axeln**: Antal bokningar
- **Blå staplar**: Senaste 4 veckorna
- **Grå staplar**: Föregående 4 veckor
- **Bredvid varandra**: Lätt att jämföra direkt

## Exempel på visuellt resultat

```
Antal bokningar
│
300│     ▓▓▓
   │     ▓▓▓
250│ ▓▓  ▓▓▓ ▓▓  ▓▓
   │ ▓▓  ▓▓▓ ▓▓  ▓▓
200│ ▓▓  ▓▓▓ ▓▓  ▓▓  ▒▒
   │ ▓▓░░▓▓▓░▓▓░░▓▓  ▒▒
150│ ▓▓░░▓▓▓░▓▓░░▓▓░░▒▒
   │ ▓▓░░▓▓▓░▓▓░░▓▓░░▒▒░░
100│ ▓▓░░▓▓▓░▓▓░░▓▓░░▒▒░░
   │ ▓▓░░▓▓▓░▓▓░░▓▓░░▒▒░░
 50│ ▓▓░░▓▓▓░▓▓░░▓▓░░▒▒░░
   │ ▓▓░░▓▓▓░▓▓░░▓▓░░▒▒░░
  0└─────────────────────────
     Mån Tis Ons Tor Fre

▓▓ = Senaste 4 veckorna
░░ = Föregående 4 veckor
```

## Tips och tricks

### 1. Färgkodning
Använd konsekvent färgschema:
- **Blå/Grön**: Aktuell period (senaste data)
- **Grå/Orange**: Jämförelseperiod (äldre data)

### 2. Tooltip
Håll muspekaren över staplar för att se exakta siffror

### 3. Förändring %
Du kan välja att visa "Förändring %" som en tredje serie, men det kan bli plottrigt. Bättre att:
- Visa förändring % i en separat tabell under diagrammet
- Eller skapa en egen Line chart för trender

### 4. Auto-refresh
För dashboard med denna widget:
- Sätt auto-refresh till 1 timme eller längre
- Data ändras bara en gång per dag (nattliga batch-jobb)

### 5. Filtrera bort helger (valfritt)
Om du bara vill se vardagar, lägg till i SQL:
```sql
WHERE wd.dow BETWEEN 1 AND 5  -- Måndag-Fredag
```

## Felsökning

### Problem: Serierna staplas ovanpå varandra
**Lösning**: Ändra "Stacking" till "None" eller "Side by side" i Display-inställningar

### Problem: Bara en serie visas
**Lösning**: Kontrollera att båda kolumnerna är valda i Y-axis i Data-inställningar

### Problem: Fel ordning på veckodagar
**Lösning**: SQL-frågan har ORDER BY wd.dow vilket sorterar korrekt (Söndag=0, Måndag=1, etc.)

### Problem: Tomma staplar för vissa dagar
**Lösning**: Det är korrekt - betyder 0 bokningar den dagen. COALESCE i SQL säkerställer att 0 visas istället för NULL.

## Avancerade alternativ

### Variant 1: Visa förändring som linje
Lägg till en Line chart overlay för "Förändring %":
1. Duplicera frågan
2. Välj bara "Veckodag" och "Förändring %"
3. Välj Line chart
4. Placera ovanpå stapeldiagrammet i dashboard

### Variant 2: Jämför flera perioder
Modifiera SQL för att jämföra 3 perioder:
- Senaste 4 veckor
- Veckor 5-8
- Veckor 9-12

### Variant 3: Månatlig jämförelse
Ändra SQL till att jämföra senaste månaden vs föregående månad:
```sql
WHERE start_time >= DATE_TRUNC('month', NOW()) - INTERVAL '1 month'
```

## Ytterligare frågor med Grouped Bar Charts

Andra användbara jämförelser:

1. **Skrivbord vs Rum per veckodag**
   - Serie 1: Skrivbordsbokningar
   - Serie 2: Rumsbokningar

2. **Plan 1 vs Plan 2 vs Plan 3**
   - Jämför bokningar per våning

3. **Timme på dagen (morgon vs eftermiddag)**
   - Serie 1: 06:00-12:00
   - Serie 2: 12:00-18:00

4. **Månad-för-månad jämförelse**
   - De senaste 12 månaderna vs samma månader förra året

Se Metabase dokumentation för fler alternativ: https://www.metabase.com/docs/latest/questions/query-builder/visualizations/bar-charts
