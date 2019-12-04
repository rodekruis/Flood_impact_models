# -------------------- Libs & Sources ------------------------
library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(ggplot2)
library(plotly)

source('scripts/create_rain_data.R')
source('scripts/prepare_glofas_data.R')
source('settings.R')


# -------------------- Settings -------------------------------
country <- "uganda"
# regions <- c("Busia")  # A vector of districts, e.g. c("KAMPALA", "KASESE"). If the vector is empty, i.e. c(), it takes all regions 
regions = c()

# -------------------- Data Extracting/Loading -------------------------
rainfall <- read.csv(file.path("raw_data", country, paste0("rainfall_", country, ".csv"))) %>%
  mutate(date = as_date(date))

impact_data <- read_csv(file.path("raw_data", country, "impact_data.csv"))
impact_data <- impact_data %>%
  mutate(flood = 1,
         district = as.character(district),
         date = as_date(date)) %>% 
  dplyr::select(date, district, flood)

# -------------------- Mutating, merging and aggregating -------
catchment_id_column <- country_settings[[country]][["catchment_id_column"]]
if (!"district" %in% names(rainfall)) {rainfall <- rainfall %>% rename("district" = catchment_id_column)}
rainfall <- create_extra_rainfall_vars(rainfall, moving_avg = FALSE, anomaly = FALSE)

# See documentation for regions in settings above
if (length(regions) != 0) {
  rainfall <- rainfall %>%
    filter(!!as.symbol(catchment_id_column) %in% regions)
}

if (include_anomaly) {
  # Temporary, only available for Katakwi
  anomalies <- read.csv('raw_data/uganda/rainfall_anomaly_katakwi.csv', stringsAsFactors = FALSE)
  anomalies$date <- as.Date(anomalies$date)
  anomalies <- anomalies %>% rename(anomaly = rainfall)
  
  rainfall <- rainfall %>%
    left_join(anomalies %>% dplyr::select(date, anomaly), by="date") 
}

df <- rainfall %>%
  mutate(district = as.character(district)) %>%
  left_join(impact_data %>% dplyr::select(district, date, flood), by = c('district', 'date'))

# Add glofas dta
glofas_data <- prep_glofas_data(country)
glofas_data <- fill_glofas_data(glofas_data)  # Glofas data is only available each three days, this will fill it
glofas_data <- make_glofas_district_matrix(glofas_data, country)  

df <- df %>%
  left_join(glofas_data, by = c("district", "date"))

write.csv(df, "scripts/shiny_uganda_data_explorer/data/shiny_explorer_input.csv", row.names = F)