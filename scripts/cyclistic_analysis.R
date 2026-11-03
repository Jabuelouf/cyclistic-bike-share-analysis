# ==============================================================================
# Cyclistic Bike-Share Analysis: Data Preparation and Exploratory Analysis
# Author: Jonathan Abuelouf
# Course: Google Data Analytics Professional Certificate Capstone
# Dataset: 2022 Divvy Bike-Share Records (Chicago, IL)
# ==============================================================================

# 1. Load Required Libraries
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(dplyr)
  library(ggplot2)
  library(plotly)
})

# 2. Ingestion and Schema Alignment
# ------------------------------------------------------------------------------
# Ingest twelve monthly CSV trip data files for calendar year 2022.
# Assumes data is placed in a local 'data/' directory or Kaggle input path.

data_dir <- "data/" # Replace with your local path if necessary

read_trip_file <- function(file_name) {
  file_path <- file.path(data_dir, file_name)
  if (file.exists(file_path)) {
    read_csv(file_path, show_col_types = FALSE)
  } else {
    warning(paste("File not found:", file_path))
    NULL
  }
}

jan <- read_trip_file("202201-divvy-tripdata.csv")
feb <- read_trip_file("202202-divvy-tripdata.csv")
mar <- read_trip_file("202203-divvy-tripdata.csv")
apr <- read_trip_file("202204-divvy-tripdata.csv")
may <- read_trip_file("202205-divvy-tripdata.csv")
jun <- read_trip_file("202206-divvy-tripdata.csv")
jul <- read_trip_file("202207-divvy-tripdata.csv")
aug <- read_trip_file("202208-divvy-tripdata.csv")
sep <- read_trip_file("202209-divvy-tripdata.csv")
oct <- read_trip_file("202210-divvy-tripdata.csv")
nov <- read_trip_file("202211-divvy-tripdata.csv")
dec <- read_trip_file("202212-divvy-tripdata.csv")

# November source schema correction:
# November trip timestamps use '%m/%d/%Y %H:%M' format rather than ISO datetime.
if (!is.null(nov)) {
  nov <- nov %>%
    mutate(
      started_at = as.POSIXct(started_at, format = "%m/%d/%Y %H:%M"),
      ended_at   = as.POSIXct(ended_at, format = "%m/%d/%Y %H:%M")
    )
}

# Combine all 12 monthly data frames
all_trips_list <- list(jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec)
all_trips <- bind_rows(compact(all_trips_list))

message("Total combined raw records: ", nrow(all_trips))

# 3. Feature Engineering
# ------------------------------------------------------------------------------
# Extract date components and calculate ride length in seconds.
all_trips <- all_trips %>%
  mutate(
    date        = as.Date(started_at),
    month       = format(date, "%m"),
    day         = format(date, "%d"),
    year        = format(date, "%Y"),
    day_of_week = format(date, "%A"),
    ride_length = as.numeric(difftime(ended_at, started_at, units = "secs"))
  )

# 4. Data Cleaning and Boundary Filtering
# ------------------------------------------------------------------------------
# Step 4a: Remove negative ride lengths (clock drift or false docking events)
cleaned_trips <- all_trips %>%
  filter(ride_length >= 0)

# Step 4b: Remove records with missing values in key fields
cleaned_trips <- na.omit(cleaned_trips)

# Step 4c: Boundary filtering
# Exclude trips shorter than 60 seconds (false starts, docking issues)
# Exclude trips longer than 54,000 seconds (15 hours, unreturned/stolen bikes)
cleaner_trips <- cleaned_trips %>%
  filter(ride_length >= 60 & ride_length <= 54000)

cleaner_trips$day_of_week <- ordered(
  cleaner_trips$day_of_week,
  levels = c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
)

message("Total records after cleaning and boundary trimming: ", nrow(cleaner_trips))
# Verified output: 4,293,274 rides (2,562,562 members / 1,730,712 casual)

# 5. Descriptive Analysis: Members vs. Casual Riders
# ------------------------------------------------------------------------------
# Rider count breakdown
rider_summary <- cleaner_trips %>%
  group_by(member_casual) %>%
  summarise(
    total_rides = n(),
    share_pct   = round(n() / nrow(cleaner_trips) * 100, 2),
    mean_duration_sec = round(mean(ride_length), 1),
    median_duration_sec = median(ride_length),
    max_duration_sec = max(ride_length),
    min_duration_sec = min(ride_length)
  )

print("--- Rider Count & Duration Summary ---")
print(rider_summary)

# Duration by day of week
duration_by_weekday <- aggregate(
  ride_length ~ member_casual + day_of_week,
  data = cleaner_trips,
  FUN = mean
)

print("--- Mean Duration (seconds) by Day of Week ---")
print(duration_by_weekday)

# Trip count and average duration by day of week
weekday_summary <- cleaner_trips %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  group_by(member_casual, weekday) %>%
  summarise(
    number_of_rides  = n(),
    average_duration = mean(ride_length),
    .groups = "drop"
  ) %>%
  arrange(member_casual, weekday)

print("--- Volume and Average Duration by Weekday ---")
print(weekday_summary)

# Monthly volume and duration patterns
monthly_summary <- cleaner_trips %>%
  mutate(month_name = month(started_at, label = TRUE)) %>%
  group_by(member_casual, month_name) %>%
  summarise(
    number_of_rides  = n(),
    average_duration = mean(ride_length),
    .groups = "drop"
  ) %>%
  arrange(member_casual, month_name)

print("--- Monthly Ride Volume & Duration ---")
print(monthly_summary)

# 6. Visualizations
# ------------------------------------------------------------------------------
# Plot 1: Ride count by weekday comparing member and casual riders
p1 <- cleaner_trips %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  group_by(member_casual, weekday) %>%
  summarise(number_of_rides = n(), .groups = "drop") %>%
  ggplot(aes(x = weekday, y = number_of_rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("casual" = "#ff8c4f", "member" = "#32efdc")) +
  labs(
    title = "Ride Volume by Day of Week: Casual vs. Member",
    x = "Day of Week",
    y = "Number of Rides",
    fill = "Rider Type"
  ) +
  theme_minimal()

print(p1)

# Plot 2: Average duration by weekday
p2 <- cleaner_trips %>%
  mutate(weekday = wday(started_at, label = TRUE)) %>%
  group_by(member_casual, weekday) %>%
  summarise(average_duration_min = mean(ride_length) / 60, .groups = "drop") %>%
  ggplot(aes(x = weekday, y = average_duration_min, fill = member_casual)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("casual" = "#ff8c4f", "member" = "#32efdc")) +
  labs(
    title = "Average Ride Duration (Minutes) by Day of Week",
    x = "Day of Week",
    y = "Average Duration (Minutes)",
    fill = "Rider Type"
  ) +
  theme_minimal()

print(p2)

# Plot 3: Monthly volume trend showing seasonal surge
p3 <- cleaner_trips %>%
  mutate(month_name = month(started_at, label = TRUE)) %>%
  group_by(member_casual, month_name) %>%
  summarise(number_of_rides = n(), .groups = "drop") %>%
  ggplot(aes(x = month_name, y = number_of_rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("casual" = "#ff8c4f", "member" = "#32efdc")) +
  labs(
    title = "Monthly Ride Volume: 2022 Seasonality",
    x = "Month",
    y = "Total Rides",
    fill = "Rider Type"
  ) +
  theme_minimal()

print(p3)
