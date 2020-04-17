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

# Join district in first lines based on link code and use district in all other places

# -------------------- Settings -------------------------------
country <- "uganda"
produce_new_rainfall_csv <- FALSE
include_anomaly <- FALSE
# districts <- c("Busia")  # A vector of districts, e.g. c("KAMPALA", "KASESE"). If the vector is empty, i.e. c(), it takes all regions 
districts <- c("Katakwi")
catchment_id_column <- country_settings[[country]][["catchment_id_column"]]

# -------------------- Data Extracting/Loading -------------------------

# Option to (re)produce rainfall csv
if (produce_new_rainfall_csv) {
  extract_rain_data_for_shapes(country, country_settings)
}

# Read in rainfall data
rainfall <- read.csv(file.path("raw_data", country, paste0("rainfall_", country, ".csv"))) %>%
  mutate(date = as_date(date),
         !!sym(catchment_id_column) := as.character(!!sym(catchment_id_column)))

# Read impact data
impact_data <- read_csv(file.path("raw_data", country, "impact_data.csv"))
impact_data <- impact_data %>%
  mutate(flood = 1,
         district = str_to_title(as.character(district)),
         !!sym(catchment_id_column) := as.character(!!sym(catchment_id_column)),
         date = as_date(date)) %>% 
  dplyr::select(date, district, !!sym(catchment_id_column), flood)

# Join district names from impact data to rainfall based on catchment_id_column, from then on use district
rainfall <- rainfall %>%
  left_join(impact_data %>% dplyr::select(!!sym(catchment_id_column), district) %>% unique(), by = catchment_id_column)

# -------------------- Mutating, merging and aggregating -------
rainfall <- create_extra_rainfall_vars(rainfall, moving_avg = FALSE, anomaly = FALSE)

# Join floods
df <- rainfall %>%
  left_join(impact_data %>% dplyr::select(-district), by = c(catchment_id_column, 'date'))

# Filter districts
if (length(districts) != 0) {
  df <- df %>%
    filter(district %in% districts)
}

if (include_anomaly) {
  # Temporary, only available for Katakwi
  anomalies <- read.csv('raw_data/uganda/rainfall_anomaly_katakwi.csv', stringsAsFactors = FALSE)
  anomalies$date <- as.Date(anomalies$date)
  anomalies <- anomalies %>% rename(anomaly = rainfall)
  
  df <- df %>%
    left_join(anomalies %>% dplyr::select(date, anomaly), by="date") 
}

# Add glofas dta
glofas_data <- prep_glofas_data(country)
glofas_data <- fill_glofas_data(glofas_data)  # Glofas data is only available each three days, this will fill it
glofas_data <- make_glofas_district_matrix(glofas_data, country)

df <- df %>%
  left_join(glofas_data, by = c("district", "date"))

# ------------------- Simple decision tree model -----------------

library(rpart)
library(rpart.plot)
library(caret)
library(rattle)

first_flood_date <- min(df %>% filter(flood == 1) %>% pull(date)) # Throw away data more than 1 year before first flood

# Remove empty columns (unrelated glofas points)
df_model <- df %>%
  select_if(~sum(!is.na(.)) > 0) %>%
  mutate(flood = as.factor(replace_na(flood, 0))) %>%
  filter(date > first_flood_date - 365)

model1 <- rpart(formula = flood ~ . , data = df_model,
                method = "class",
                minsplit = 9, minbucket = 3)

summary(model1)

rpart.plot(model1, type = 2, extra = 1)
confusionMatrix(predict(model1, type = "class"), reference=as.factor(df_model$flood))

penal <- matrix(c(0, 1, 8, 0), nrow = 2, byrow = TRUE)

model2 <- rpart(formula = flood ~ . , data = df_model,
                method = "class",
                parms = (list(loss=penal)),
                minsplit = 9, minbucket = 3)

confusionMatrix(predict(model2, type = "class"), reference=as.factor(df_model$flood))$table

# summary(model2)
rpart.plot(model2, type = 2, extra=1)

fancyRpartPlot(model2, cex=0.7)

