# -------------------- Libs & Sources ------------------------
library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(ggplot2)
library(plotly)

source('scripts/create_rain_data.R')
source('scripts/prepare_glofas_data.R')


# -------------------- Settings -------------------------------

shapefile_path <- file.path("shapes", "uganda_catchment", "ug_cat.shp")
layer <- "ug_cat"
p_code_column <- "N___N___PC"  # The column in the shapefile containing the pcode

rainfile_path <- file.path("raw_data", "rainfall_catchment.csv")
produce_new_rainfall_csv <- FALSE
regions <- c("KATAKWI")  # A vector of districts, e.g. c("KAMPALA", "KASESE"). If the vector is empty, i.e. c(), it takes all regions 
# regions = c()

# -------------------- Data Extracting/Loading -------------------------

# Option to (re)produce rainfall csv
if (produce_new_rainfall_csv) {
  extract_rain_data_for_shapes(shapefile_path, layer, rainfile_path)
}

rainfall <- read.csv(rainfile_path) %>%
  mutate(date = as_date(date))

impact_data <- read_csv("raw_data/own_impact_data.csv")
impact_data <- impact_data %>%
  mutate(date = as_date(Date),
         district = str_to_upper(Area),
         flood = 1) %>% 
  dplyr::select(-Date, -Area, -link)


# -------------------- Mutating, merging and aggregating -------
rainfall <- create_extra_rainfall_vars(rainfall, moving_avg = FALSE, anomaly = FALSE)

# See documentation for regions in settings above
if (length(regions) != 0) {
  rainfall <- rainfall %>%
    filter(district %in% regions)
}

# Temporary, only available for Katakwi
anomalies <- read.csv('raw_data/rainfall_anomaly_katakwi.csv', stringsAsFactors = FALSE)
anomalies$date <- as.Date(anomalies$date)
anomalies <- anomalies %>% rename(anomaly = rainfall)

rainfall <- rainfall %>%
  left_join(anomalies %>% dplyr::select(date, anomaly), by="date")


glofas_data <- prep_glofas_data()
glofas_data <- fill_glofas_data(glofas_data)  # Glofas data is only available each three days, this will fill it
glofas_data <- make_glofas_district_matrix(glofas_data)


df <- rainfall %>%
  mutate(district = as.character(district)) %>%
  left_join(impact_data %>% dplyr::select(district, date, flood), by = c('district', 'date')) %>%
  left_join(glofas_data, by = c("district", "date"))

# write.csv(df, 'output/prepped_data.csv', row.names=FALSE)
# write.csv(df, 'shiny_app/data/prepped_data.csv', row.names=FALSE)


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

# summary(model1)

rpart.plot(model1, type = 2, extra = 1)
confusionMatrix(predict(model1, type = "class"), reference=as.factor(df_model$flood))

penal <- matrix(c(0, 1, 10, 0), nrow = 2, byrow = TRUE)

model2 <- rpart(formula = flood ~ . , data = df_model,
                method = "class",
                parms = (list(loss=penal)),
                minsplit = 9, minbucket = 3)

confusionMatrix(predict(model2, type = "class"), reference=as.factor(df_model$flood))$table

# summary(model2)
rpart.plot(model2, type = 2, extra=1)

fancyRpartPlot(model2, cex=0.7)
