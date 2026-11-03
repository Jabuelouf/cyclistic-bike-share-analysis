-- ==============================================================================
-- Google BigQuery SQL: Cyclistic Ride-Share Exploratory Data Analysis
-- Author: Jonathan Abuelouf
-- Project: Cyclistic Bike-Share Case Study (Google Data Analytics Capstone)
-- Purpose: Ingestion, cleaning, metric aggregation, and behavioral comparisons
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CLEANING & BOUNDARY FILTERING VIEW
-- Table: `cyclistic_data.combined_2022_trips`
-- Rules:
--   - started_at and ended_at must be non-null
--   - ride_length calculated as TIMESTAMP_DIFF in seconds
--   - Filter out negative durations (clock skew / system errors)
--   - Filter trips under 60 seconds (accidental dock release / aborts)
--   - Filter trips over 54,000 seconds (15 hours, unreturned / stolen bikes)
-- ------------------------------------------------------------------------------
WITH cleaned_rides AS (
  SELECT
    ride_id,
    rideable_type,
    started_at,
    ended_at,
    start_station_name,
    start_station_id,
    end_station_name,
    end_station_id,
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    member_casual,
    TIMESTAMP_DIFF(ended_at, started_at, SECOND) AS ride_length_seconds,
    EXTRACT(DAYOFWEEK FROM started_at) AS day_of_week_num, -- 1 = Sunday, 7 = Saturday
    FORMAT_DATE('%A', DATE(started_at)) AS day_of_week_name,
    EXTRACT(MONTH FROM started_at) AS month_num,
    FORMAT_DATE('%B', DATE(started_at)) AS month_name,
    DATE(started_at) AS ride_date
  FROM
    `cyclistic_data.combined_2022_trips`
  WHERE
    started_at IS NOT NULL
    AND ended_at IS NOT NULL
    AND start_station_name IS NOT NULL
    AND end_station_name IS NOT NULL
    AND TIMESTAMP_DIFF(ended_at, started_at, SECOND) >= 60
    AND TIMESTAMP_DIFF(ended_at, started_at, SECOND) <= 54000
)

-- ------------------------------------------------------------------------------
-- 2. OVERALL VOLUME AND DURATION BENCHMARKS BY RIDER SEGMENT
-- Expected Output: 4,293,274 total cleaned records
--   - Casual: ~1.73M rides (40.3%)
--   - Member: ~2.56M rides (59.7%)
-- ------------------------------------------------------------------------------
SELECT
  member_casual,
  COUNT(ride_id) AS total_rides,
  ROUND(COUNT(ride_id) * 100.0 / SUM(COUNT(ride_id)) OVER(), 2) AS ride_share_pct,
  ROUND(AVG(ride_length_seconds) / 60.0, 2) AS avg_duration_minutes,
  ROUND(APPROX_QUANTILES(ride_length_seconds, 2)[OFFSET(1)] / 60.0, 2) AS median_duration_minutes,
  MIN(ride_length_seconds) AS min_duration_seconds,
  MAX(ride_length_seconds) AS max_duration_seconds
FROM
  cleaned_rides
GROUP BY
  member_casual;

-- ------------------------------------------------------------------------------
-- 3. DAY OF WEEK USAGE: COMMUTING VS. LEISURE BEHAVIOR
-- Members peak Monday through Friday (commute hours).
-- Casual riders peak Friday through Sunday with substantially longer durations.
-- ------------------------------------------------------------------------------
SELECT
  day_of_week_num,
  day_of_week_name,
  member_casual,
  COUNT(ride_id) AS total_rides,
  ROUND(AVG(ride_length_seconds) / 60.0, 2) AS avg_duration_minutes
FROM
  cleaned_rides
GROUP BY
  day_of_week_num,
  day_of_week_name,
  member_casual
ORDER BY
  member_casual,
  day_of_week_num;

-- ------------------------------------------------------------------------------
-- 4. MONTHLY SEASONALITY AND VOLUME SURGE (2022)
-- Identifies the dramatic volume ramp between May and September for casual riders.
-- ------------------------------------------------------------------------------
SELECT
  month_num,
  month_name,
  member_casual,
  COUNT(ride_id) AS total_rides,
  ROUND(AVG(ride_length_seconds) / 60.0, 2) AS avg_duration_minutes
FROM
  cleaned_rides
GROUP BY
  month_num,
  month_name,
  member_casual
ORDER BY
  member_casual,
  month_num;

-- ------------------------------------------------------------------------------
-- 5. TOP 10 ORIGIN STATIONS BY RIDER TYPE
-- Casual riders concentrate along the lakefront and tourist destinations.
-- Members concentrate near train terminals, residential neighborhoods, and business hubs.
-- ------------------------------------------------------------------------------
WITH ranked_stations AS (
  SELECT
    member_casual,
    start_station_name,
    COUNT(ride_id) AS ride_count,
    ROUND(AVG(ride_length_seconds) / 60.0, 2) AS avg_duration_minutes,
    ROW_NUMBER() OVER(PARTITION BY member_casual ORDER BY COUNT(ride_id) DESC) AS rank
  FROM
    cleaned_rides
  GROUP BY
    member_casual,
    start_station_name
)
SELECT
  rank,
  member_casual,
  start_station_name,
  ride_count,
  avg_duration_minutes
FROM
  ranked_stations
WHERE
  rank <= 10
ORDER BY
  member_casual,
  rank;
