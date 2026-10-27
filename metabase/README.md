# Metabase Dashboard-frågor för Awaio

Denna mapp innehåller SQL-frågor för att skapa dashboards i Metabase.

## Models

Undermappen `models/` innehåller Metabase Models — kurerade datakällor som
de flesta frågor bygger på istället för att joina råa tabeller själva. En
fil per model:

| Fil | Model | Syfte |
|---|---|---|
| `models/01_entities_with_hierarchy.sql` | Entities With Hierarchy | Plattar ut `entities`-trädet så `floor_name` och `area_name` är vanliga kolumner. |
| `models/02_bookings_enriched.sql` | Bookings Enriched | Flat fakttabell: bokning + entity + user + duration + weekday + floor/area. Driver ~80 % av dashboard-frågor. |
| `models/03_daily_entity_metrics.sql` | Daily Entity Metrics | Förberedd per-dygn-per-entity-aggregering för trendfrågor. |
| `models/04_user_weekly_mobility.sql` | User Weekly Mobility | Per vecka + användare: unika entiteter/skrivbord/rum/våningar, discovery-score. |
| `models/05_entity_sharing_metrics.sql` | Entity Sharing Metrics | Per entity: unika användare, dominans-ratio (top_user_share) för "demokrati"-dashboards. |

### Så skapar/uppdaterar du modellerna

```bash
python3 scripts/create_metabase_models.py
```

Scriptet kräver `METABASE_API_KEY` i `.env` (skapas i **Admin settings →
Authentication → API Keys**). Det är idempotent — körs det igen uppdateras
befintliga modeller med senaste SQL istället för att duplicera.



## Översikt

| Fråga | Beskrivning | Visualisering |
|-------|-------------|---------------|
| 01_bokningar_per_veckodag.sql | Antal bokningar per veckodag | Column chart |
| 02_top10_populäraste_skrivbord.sql | De 10 mest bokade skrivborden | Horizontal bar chart |
| 03_top10_skrivbord_flest_unika_användare.sql | Skrivbord med flest olika användare | Horizontal bar chart / Table |
| 04_top10_populäraste_rum_med_snitttid.sql | Mest bokade rum med genomsnittlig bokningstid | Table |
| 05_top10_mest_aktiva_användare_pivot.sql | Mest aktiva användare med deras top 5 skrivbord | Table (pivot) |
| 06_senaste_bokningar_skrivbord.sql | De 5 senaste bokade skrivborden (realtid) | Table |
| 07_senaste_bokningar_rum.sql | De 5 senaste bokade rummen (realtid) | Table |
| 08_senaste_bokningar_kombinerad.sql | De 5 senaste bokningarna (alla typer) | Table |
| 09_veckodag_jamforelse_4veckor.sql | Jämförelse bokningar per veckodag (senaste vs tidigare 4 veckor) | Grouped Bar Chart |
| 10_top10_minst_populära_rum.sql | De 10 minst populära rummen (underutnyttjade) | Horizontal bar chart / Table |
| 11_obokade_rum.sql | Rum som aldrig har bokats | Table |
| 12_top10_minst_populära_skrivbord.sql | De 10 minst populära skrivborden (underutnyttjade) | Horizontal bar chart / Table |
| 13_obokade_skrivbord.sql | Skrivbord som aldrig har bokats | Table |

## Hur du använder frågorna

### 1. Öppna Metabase
```
http://localhost:3000
```

### 2. Skapa en ny fråga
1. Klicka på **"New"** → **"SQL query"**
2. Välj **"awaio_db"** databas
3. Kopiera innehållet från någon av SQL-filerna
4. Klicka **"Run"** för att testa
5. Välj lämplig visualisering (se tabellen ovan)
6. Klicka **"Save"** och ge frågan ett namn

### 3. Skapa Dashboard
1. Klicka på **"New"** → **"Dashboard"**
2. Ge den ett namn: **"Awaio Bokningsanalys"**
3. Klicka **"Add a question"**
4. Välj dina sparade frågor
5. Justera layout och storlek

## Rekommenderad Dashboard-layout

### Dashboard 1: Översikt och statistik
```
+-----------------------------------+-----------------------------------+
|                                   |                                   |
|  Bokningar per veckodag           |  Top 10 populäraste skrivbord     |
|  (Column chart)                   |  (Horizontal bar chart)           |
|                                   |                                   |
+-----------------------------------+-----------------------------------+
|                                   |                                   |
|  Top 10 skrivbord                 |  Top 10 populäraste rum           |
|  - flest unika användare          |  med snitttid                     |
|  (Horizontal bar chart)           |  (Table)                          |
|                                   |                                   |
+-----------------------------------+-----------------------------------+
|                                                                       |
|  Top 10 mest aktiva användare med deras 5 vanligaste skrivbord       |
|  (Table - full width)                                                 |
|                                                                       |
+-----------------------------------------------------------------------+
```

### Dashboard 2: Realtidsöversikt (widgets)
```
+-------------------------------------+-------------------------------------+
|                                     |                                     |
|  Senaste bokade skrivbord (5 st)    |  Senaste bokade rum (5 st)          |
|  (Table - auto-refresh)             |  (Table - auto-refresh)             |
|                                     |                                     |
+-------------------------------------+-------------------------------------+
|                                                                             |
|  Senaste bokningar - alla typer (5 st)                                      |
|  (Table - auto-refresh, full width)                                         |
|                                                                             |
+-----------------------------------------------------------------------------+
```

**Tips för realtidswidgets:**
- Ställ in auto-refresh till 1-5 minuter
- Kompakta kolumner för bättre översikt
- Använd färgkodning för status (grön=pågående, grå=avslutad, blå=kommande)

## Tips för Metabase

### Visualiseringsval
- **Column/Bar chart**: Bra för jämförelser
- **Table**: Bra för detaljerad data med många kolumner
- **Line chart**: Bra för trender över tid

### Filtrering
Du kan lägga till filter i Metabase UI:
- Datumfilter för att visa endast senaste månaden
- Entity-filter för att fokusera på specifika våningar/områden
- Användarfilter för att se specifika personers bokningar

### Automatisk uppdatering
Ställ in dashboard att uppdatera automatiskt:
1. Öppna dashboard
2. Klicka på **"..."** → **"Dashboard settings"**
3. Under **"Auto-refresh"**, välj intervall (t.ex. 1 timme)

**För realtidswidgets (frågor 06-08):**
- Använd kortare refresh-intervall: 1-5 minuter
- Perfekt för att visa på stora skärmar i kontoret
- Visar alltid de senaste bokningarna

## Ytterligare frågor

Om du vill ha fler analyser, här är några förslag:

### Tidsbaserade analyser
- Bokningar per timme på dagen
- Bokningar per vecka/månad (trend)
- Mest populära tider för skrivbordsbokningar

### Användningsgrad
- % av tillgänglig tid som är bokad per entity
- Outnyttjade skrivbord/rum
- Peak-tider vs lågtrafik-tider

### Användaranalys
- Genomsnittlig bokningstid per användare
- Användare som bokar mest i förväg
- Mest aktiva användare per område

Se CLAUDE.md för mer information om projektet.
