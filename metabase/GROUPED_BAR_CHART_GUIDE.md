# Guide: Creating a Grouped Bar Chart in Metabase

## Overview

This guide shows how to create a bar chart with several series (a grouped bar chart) in Metabase to compare bookings between different periods.

## Example: weekday comparison (question 09)

### Step 1: Run the SQL question

1. Open Metabase: http://localhost:3000
2. Click **"New"** → **"SQL query"**
3. Choose the database: **"awaio_db"**
4. Copy the contents of `09_weekday_comparison_4weeks.sql`
5. Click **"Run"**

You should see data like:
```
Weekday    | Last 4 weeks | Previous 4 weeks | Change %
-----------|--------------|------------------|---------
1-Monday   |     189      |       273        |  -30.8
2-Tuesday  |     229      |       322        |  -28.9
...
```

### Step 2: Choose a visualisation

1. Click the **"Visualization"** button (next to Run)
2. Choose **"Bar"**

### Step 3: Configure the chart

In the visualisation settings:

#### Data tab:
- **X-axis**: `Weekday`
- **Y-axis**:
  - ✅ `Last 4 weeks`
  - ✅ `Previous 4 weeks`
  - ❌ `Change %` (optional)

#### Display tab:
- **Chart type**: Column chart (vertical bars)
- **Stacking**: **"None"** or **"Side by side"** (important!)
  - **NOT** "Stacked" - that puts the series on top of each other
- **Show values on data points**: optional (can get cluttered)

#### Formatting tab:
- **Colors**:
  - Series 1 (Last 4 weeks): blue or green
  - Series 2 (Previous 4 weeks): grey or orange
- **Legend**: show the legend to explain the series

#### Axes tab:
- **Y-axis label**: "Number of bookings"
- **X-axis label**: "Weekday" (or leave empty)
- **Y-axis scale**: Auto (or manual if you prefer)

### Step 4: Save the question

1. Click **"Save"**
2. Name: "Weekday comparison (4 weeks)"
3. Description: "Compares bookings per weekday between the last 4 weeks and the previous 4 weeks"
4. Collection: choose or create "Awaio Analytics"

### Step 5: Add it to a dashboard

1. Go to your dashboard or create a new one
2. Click **"Add a question"**
3. Choose "Weekday comparison (4 weeks)"
4. Adjust the size (recommended: full or half width)
5. Click **"Save"**

## Result

You get a bar chart that shows:
- **X-axis**: weekdays (Monday-Sunday)
- **Y-axis**: number of bookings
- **Blue bars**: last 4 weeks
- **Grey bars**: previous 4 weeks
- **Side by side**: easy to compare directly

## Example of the visual result

```
Number of bookings
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
     Mon Tue Wed Thu Fri

▓▓ = Last 4 weeks
░░ = Previous 4 weeks
```

## Tips and tricks

### 1. Colour coding
Use a consistent colour scheme:
- **Blue/Green**: current period (latest data)
- **Grey/Orange**: comparison period (older data)

### 2. Tooltip
Hover over the bars to see the exact numbers

### 3. Change %
You can show "Change %" as a third series, but it can get cluttered. Better to:
- Show the change % in a separate table below the chart
- Or create a separate line chart for trends

### 4. Auto-refresh
For a dashboard with this widget:
- Set auto-refresh to 1 hour or longer
- The data changes at most once per hour (scheduler runs)

### 5. Filter out weekends (optional)
If you only want to see weekdays, add to the SQL:
```sql
WHERE wd.dow BETWEEN 1 AND 5  -- Monday-Friday
```

## Troubleshooting

### Problem: the series are stacked on top of each other
**Solution**: change "Stacking" to "None" or "Side by side" in the Display settings

### Problem: only one series is shown
**Solution**: check that both columns are selected under Y-axis in the Data settings

### Problem: the weekdays are in the wrong order
**Solution**: the SQL question has ORDER BY wd.dow, which sorts correctly (Sunday=0, Monday=1, etc.)

### Problem: empty bars for some days
**Solution**: that is correct - it means 0 bookings that day. COALESCE in the SQL makes sure 0 is shown instead of NULL.

## Advanced options

### Variant 1: show the change as a line
Add a line chart overlay for "Change %":
1. Duplicate the question
2. Select only "Weekday" and "Change %"
3. Choose Line chart
4. Place it on top of the bar chart in the dashboard

### Variant 2: compare several periods
Modify the SQL to compare 3 periods:
- Last 4 weeks
- Weeks 5-8
- Weeks 9-12

### Variant 3: monthly comparison
Change the SQL to compare the last month vs the previous month:
```sql
WHERE start_time >= DATE_TRUNC('month', NOW()) - INTERVAL '1 month'
```

## More questions with grouped bar charts

Other useful comparisons:

1. **Desks vs rooms per weekday**
   - Series 1: desk bookings
   - Series 2: room bookings

2. **Plan 1 vs Plan 2 vs Plan 3**
   - Compare bookings per floor

3. **Hour of the day (morning vs afternoon)**
   - Series 1: 06:00-12:00
   - Series 2: 12:00-18:00

4. **Month-over-month comparison**
   - The last 12 months vs the same months last year

See the Metabase documentation for more options: https://www.metabase.com/docs/latest/questions/query-builder/visualizations/bar-charts
