# Metabase dashboard questions for Awaio

This folder contains SQL questions for building dashboards in Metabase.

## Models

The `models/` subfolder contains Metabase Models — curated data sources that
most questions build on instead of joining the raw tables themselves. One
file per model:

| File | Model | Purpose |
|---|---|---|
| `models/01_entities_with_hierarchy.sql` | Entities With Hierarchy | Flattens the `entities` tree so `floor_name` and `area_name` are plain columns. |
| `models/02_bookings_enriched.sql` | Bookings Enriched | Flat fact table: booking + entity + user + duration + weekday + floor/area. Drives ~80 % of the dashboard questions. |
| `models/03_daily_entity_metrics.sql` | Daily Entity Metrics | Pre-built per-day, per-entity aggregation for trend questions. |
| `models/04_user_weekly_mobility.sql` | User Weekly Mobility | Per week + user: unique entities/desks/rooms/floors, discovery score. |
| `models/05_entity_sharing_metrics.sql` | Entity Sharing Metrics | Per entity: unique users, dominance ratio (top_user_share) for "democracy" dashboards. |

### Creating/updating the models

```bash
python3 scripts/create_metabase_models.py
```

The script needs `METABASE_API_KEY` in `.env` (created under **Admin settings →
Authentication → API Keys**). It is idempotent — running it again updates the
existing models with the latest SQL instead of creating duplicates.



## Overview

| Question | Description | Visualisation |
|-------|-------------|---------------|
| 01_bookings_per_weekday.sql | Number of bookings per weekday | Column chart |
| 02_top10_most_popular_desks.sql | The 10 most booked desks | Horizontal bar chart |
| 03_top10_desks_most_unique_users.sql | Desks with the most distinct users | Horizontal bar chart / Table |
| 04_top10_most_popular_rooms_avg_duration.sql | Most booked rooms with average booking duration | Table |
| 05_top10_most_active_users_pivot.sql | Most active users with their top 5 desks | Table (pivot) |
| 06_latest_bookings_desks.sql | The 5 most recently booked desks (real time) | Table |
| 07_latest_bookings_rooms.sql | The 5 most recently booked rooms (real time) | Table |
| 08_latest_bookings_combined.sql | The 5 most recent bookings (all types) | Table |
| 09_weekday_comparison_4weeks.sql | Bookings per weekday compared (last vs previous 4 weeks) | Grouped Bar Chart |
| 10_top10_least_popular_rooms.sql | The 10 least popular rooms (under-used) | Horizontal bar chart / Table |
| 11_unbooked_rooms.sql | Rooms that have never been booked | Table |
| 12_top10_least_popular_desks.sql | The 10 least popular desks (under-used) | Horizontal bar chart / Table |
| 13_unbooked_desks.sql | Desks that have never been booked | Table |

## How to use the questions

### 1. Open Metabase
```
http://localhost:3000
```

### 2. Create a new question
1. Click **"New"** → **"SQL query"**
2. Choose the **"awaio_db"** database
3. Copy the contents of one of the SQL files
4. Click **"Run"** to test it
5. Choose a suitable visualisation (see the table above)
6. Click **"Save"** and give the question a name

### 3. Create a dashboard
1. Click **"New"** → **"Dashboard"**
2. Give it a name: **"Awaio Booking Analysis"**
3. Click **"Add a question"**
4. Choose your saved questions
5. Adjust the layout and sizes

## Recommended dashboard layout

### Dashboard 1: Overview and statistics
```
+-----------------------------------+-----------------------------------+
|                                   |                                   |
|  Bookings per weekday             |  Top 10 most popular desks        |
|  (Column chart)                   |  (Horizontal bar chart)           |
|                                   |                                   |
+-----------------------------------+-----------------------------------+
|                                   |                                   |
|  Top 10 desks                     |  Top 10 most popular rooms        |
|  - most unique users              |  with average duration            |
|  (Horizontal bar chart)           |  (Table)                          |
|                                   |                                   |
+-----------------------------------+-----------------------------------+
|                                                                       |
|  Top 10 most active users with their 5 most common desks             |
|  (Table - full width)                                                 |
|                                                                       |
+-----------------------------------------------------------------------+
```

### Dashboard 2: Real-time overview (widgets)
```
+-------------------------------------+-------------------------------------+
|                                     |                                     |
|  Latest booked desks (5)            |  Latest booked rooms (5)            |
|  (Table - auto-refresh)             |  (Table - auto-refresh)             |
|                                     |                                     |
+-------------------------------------+-------------------------------------+
|                                                                             |
|  Latest bookings - all types (5)                                            |
|  (Table - auto-refresh, full width)                                         |
|                                                                             |
+-----------------------------------------------------------------------------+
```

**Tips for real-time widgets:**
- Set auto-refresh to 1-5 minutes
- Compact columns for a better overview
- Use colour coding for status (green = ongoing, grey = finished, blue = upcoming)

## Metabase tips

### Choosing a visualisation
- **Column/Bar chart**: good for comparisons
- **Table**: good for detailed data with many columns
- **Line chart**: good for trends over time

### Filtering
You can add filters in the Metabase UI:
- A date filter to show only the last month
- An entity filter to focus on specific floors/areas
- A user filter to see specific people's bookings

### Automatic refresh
Set the dashboard to refresh automatically:
1. Open the dashboard
2. Click **"..."** → **"Dashboard settings"**
3. Under **"Auto-refresh"**, choose an interval (e.g. 1 hour)

**For the real-time widgets (questions 06-08):**
- Use a shorter refresh interval: 1-5 minutes
- Ideal for showing on large screens in the office
- Always shows the latest bookings

## More questions

If you want more analyses, here are some ideas:

### Time-based analyses
- Bookings per hour of the day
- Bookings per week/month (trend)
- Most popular times for desk bookings

### Utilisation
- % of available time that is booked per entity
- Unused desks/rooms
- Peak times vs quiet times

### User analysis
- Average booking duration per user
- Users who book furthest in advance
- Most active users per area

See CLAUDE.md for more information about the project.
