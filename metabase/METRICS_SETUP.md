# Metabase Metrics Setup Guide

This document describes how to create reusable Metrics in Metabase for the Awaio project.

## What are Metrics?

Metrics are pre-configured aggregations that can be reused across many questions and dashboards. They ensure consistent calculations and make analysis easier for non-technical users.

## Predefined Metrics for Awaio

The following Metrics cover the most common calculations for booking analysis.

---

## 1. Number of bookings

**Name:** `Number of bookings`
**Table:** `bookings`
**Type:** Count of rows
**Filter:** None (counts all bookings)

### Create in Metabase:
1. Go to **Settings** → **Admin** → **Table Metadata**
2. Choose the database: `awaio_db`
3. Find the table: `bookings`
4. Click **+ Add a Metric**
5. Fill in:
   - **Name:** `Number of bookings`
   - **Description:** `Total number of bookings in the system`
   - **Definition:** choose `Count of rows`
6. Save

### Usage example:
```sql
-- In the Query Builder:
SELECT "Number of bookings" FROM bookings
GROUP BY entity_id

-- Result: number of bookings per entity
```

---

## 2. Average booking duration (hours)

**Name:** `Average booking duration (hours)`
**Table:** `bookings`
**Type:** Custom expression
**Formula:** `AVG([end_time] - [start_time]) / 3600`

### Create in Metabase:
1. Go to **Settings** → **Admin** → **Table Metadata**
2. Choose the database: `awaio_db`
3. Find the table: `bookings`
4. Click **+ Add a Metric**
5. Fill in:
   - **Name:** `Average booking duration (hours)`
   - **Description:** `Average length of bookings in hours (end_time - start_time)`
   - **Definition:** choose `Custom Expression`
   - **Expression:**
     ```
     Average([End Time] - [Start Time]) / interval(1, 'hour')
     ```
     *NOTE: the Metabase GUI may use a different syntax; also try:*
     ```
     AVG(([End Time] - [Start Time]) / 3600000000000)
     ```
     *(PostgreSQL interval to seconds, then to hours)*

### Alternative SQL for a Native Query:
If the Custom Expression is awkward in the GUI, use a Native Query:
```sql
SELECT
    entity_id,
    AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600) as avg_booking_duration_hours
FROM bookings
GROUP BY entity_id
```

### Usage examples:
- Compare the average booking duration between rooms and desks
- Identify resources with unusually long/short bookings
- Trend over time (is the average increasing/decreasing?)

---

## 3. Total booked time (hours)

**Name:** `Total booked time (hours)`
**Table:** `bookings`
**Type:** Custom expression
**Formula:** `SUM([end_time] - [start_time]) / 3600`

### Create in Metabase:
1. Go to **Settings** → **Admin** → **Table Metadata**
2. Choose the database: `awaio_db`
3. Find the table: `bookings`
4. Click **+ Add a Metric**
5. Fill in:
   - **Name:** `Total booked time (hours)`
   - **Description:** `Total summed time of all bookings in hours`
   - **Definition:** choose `Custom Expression`
   - **Expression:**
     ```
     Sum([End Time] - [Start Time]) / interval(1, 'hour')
     ```

### Alternative SQL for a Native Query:
```sql
SELECT
    entity_id,
    SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600) as total_booked_hours
FROM bookings
GROUP BY entity_id
```

### Usage examples:
- Total utilisation time per room
- Identify the most used resources (in total)
- Capacity planning (how many hours are booked per week/month?)

---

## 4. Unique users

**Name:** `Unique users`
**Table:** `bookings`
**Type:** Count of distinct values
**Field:** `owner_id`

### Create in Metabase:
1. Go to **Settings** → **Admin** → **Table Metadata**
2. Choose the database: `awaio_db`
3. Find the table: `bookings`
4. Click **+ Add a Metric**
5. Fill in:
   - **Name:** `Unique users`
   - **Description:** `Number of unique users who have made bookings`
   - **Definition:** choose `Distinct values of...`
   - **Column:** choose `Owner ID`
6. Save

### Usage example:
```sql
-- In the Query Builder:
SELECT "Unique users" FROM bookings
GROUP BY entity_id

-- Result: number of unique users per entity
```

### Usage examples:
- Identify rooms with many vs few unique users
- Popularity over time (is the number of users increasing?)
- Compare desks vs rooms (which have the broader user base?)

---

## Technical details: time calculations in PostgreSQL

### PostgreSQL INTERVAL arithmetic:
```sql
-- The difference between timestamps gives an INTERVAL
end_time - start_time  -- Result: '4 hours 30 minutes'

-- Convert the INTERVAL to seconds
EXTRACT(EPOCH FROM (end_time - start_time))  -- Result: 16200 (seconds)

-- Convert seconds to hours
EXTRACT(EPOCH FROM (end_time - start_time)) / 3600  -- Result: 4.5 (hours)
```

### Metabase Custom Expression syntax:
Metabase uses its own syntax for time calculations. If the expressions above do not work, try:

**For hours:**
```
([End Time] - [Start Time]) / 3600000000000
```
*(Metabase may represent intervals as nanoseconds internally)*

**Or use a Native SQL query instead:**
```sql
SELECT
    AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600)
FROM bookings
```

---

## Combining Metrics with Segments

### Example: create a Segment for "Long bookings"

1. Go to **Settings** → **Admin** → **Table Metadata**
2. Choose the table: `bookings`
3. Click **+ Add a Segment**
4. Name: `Long bookings (>4h)`
5. Filter:
   ```
   [Total booked time (hours)] > 4
   ```
   *Or:*
   ```
   ([End Time] - [Start Time]) > interval(4, 'hour')
   ```

### Combine Segment + Metric:
- **Segment:** "Long bookings (>4h)"
- **Metric:** "Number of bookings"
- **Result:** the number of bookings longer than 4 hours

---

## Using Metrics in SQL queries

You **cannot** reference Metrics directly in Native SQL queries. But Metrics are useful when you use the **Query Builder** (GUI).

### Strategy:
1. **Create Metrics for basic aggregations** (as above)
2. **Use the Query Builder for simple questions** → choose Metrics from the dropdown
3. **Use Native SQL for complex analyses** → write the formula directly (as in the existing queries)

### Example: an existing query with Metric logic

**Existing SQL (metabase/04_top10_most_popular_rooms_avg_duration.sql):**
```sql
SELECT
    e.name AS room,
    COUNT(b.id) AS bookings,  -- This is the Metric "Number of bookings"
    ROUND(AVG(EXTRACT(EPOCH FROM (b.end_time - b.start_time)) / 3600)::numeric, 1) AS avg_hours_per_booking  -- This is the Metric "Average booking duration"
FROM bookings b
JOIN entities e ON b.entity_id = e.id
WHERE e.group_tag = 'room'
GROUP BY e.id, e.name
ORDER BY bookings DESC
LIMIT 10;
```

**With the Query Builder + Metrics:**
1. Choose the table: `bookings`
2. Join with: `entities` (via `entity_id`)
3. Filter: `group_tag = 'room'`
4. Summarize:
   - Metric: "Number of bookings"
   - Metric: "Average booking duration (hours)"
5. Group by: `entities.name`
6. Sort: "Number of bookings" descending
7. Limit: 10

---

## Verifying Metrics

### Test 1: compare a Metric with direct SQL

**SQL query:**
```sql
SELECT COUNT(*) FROM bookings;
```

**Query Builder:**
1. Choose the table: `bookings`
2. Summarize: "Number of bookings"
3. The result should match the SQL question

### Test 2: check the average booking duration

**SQL query:**
```sql
SELECT AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600)
FROM bookings;
```

**Query Builder:**
1. Choose the table: `bookings`
2. Summarize: "Average booking duration (hours)"
3. The result should match (within rounding)

---

## Troubleshooting

### Problem: the "Custom Expression" does not work

**Solution:** the Metabase GUI can have limitations for complex time calculations. Use Native SQL instead:

```sql
-- Create a SQL "Saved Question" instead of a Metric
SELECT
    'Average booking duration' AS metric_name,
    ROUND(AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600)::numeric, 2) AS value
FROM bookings;
```

### Problem: the Metric shows the wrong value

**Check:**
1. **Time zone:** are `end_time` and `start_time` in the right time zone?
2. **Unit:** is the interval in seconds, milliseconds or nanoseconds?
3. **NULL values:** filter them out with `WHERE end_time IS NOT NULL`

### Problem: cannot find "Add a Metric"

**Solution:**
- Metrics require admin rights
- Check that you are logged in as an admin user
- If the button is missing, check the Metabase version (older versions have a different UI)

---

## Next steps

### More useful Metrics:
1. **"Number of bookings (rooms)"** - COUNT with the filter `group_tag = 'room'`
2. **"Number of bookings (desks)"** - COUNT with the filter `group_tag = 'desk'`
3. **"Average capacity per booking"** - AVG(entity.capacity_normal)
4. **"Peak hours (9-17)"** - SUM with a filter on EXTRACT(HOUR FROM start_time)

### Segments to create:
1. **"Long bookings (>4h)"**
2. **"Short bookings (<1h)"**
3. **"Office hours (9-17)"**
4. **"Weekend bookings"**
5. **"Last 30 days"**

These can be combined with Metrics for powerful ad hoc analysis without SQL knowledge!

---

## References

- [Metabase Metrics Documentation](https://www.metabase.com/docs/latest/data-modeling/metrics)
- [PostgreSQL Interval Arithmetic](https://www.postgresql.org/docs/current/functions-datetime.html)
- Project: `/metabase/*.sql` - existing SQL queries that can benefit from Metrics
