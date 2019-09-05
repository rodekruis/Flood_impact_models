# -------------------- Libs & Sources ------------------------
library(dplyr)
library(readr)
library(lubridate)
library(stringr)

source('scripts/create_rain_data.R')
source('scripts/prepare_glofas_data.R')


# -------------------- Settings -------------------------------

shapefile_path <- file.path("shapes", "uganda_catchment", "ug_cat.shp")
layer <- "ug_cat"
p_code_column <- "N___N___PC"  # The column in the shapefile containing the pcode

rainfile_path <- file.path("raw_data", "rainfall_catchment.csv")
produce_new_rainfall_csv <- FALSE
regions <- c("KATAKWI", "KASESE", "KAABONG")  # A vector of districts, e.g. c("KAMPALA", "KASESE"). If the vector is empty, i.e. c(), it takes all regions 


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
  dplyr::select(-Date, -Area, -link, -`Extra sources`)


# -------------------- Mutating, merging and aggregating -------
rainfall <- create_extra_rainfall_vars(rainfall)


# See documentation for regions in settings above
if (length(regions) != 0) {
  rainfall <- rainfall %>%
    filter(district %in% regions)
}

glofas_data <- prep_glofas_data()
glofas_data <- make_glofas_district_matrix(glofas_data)


df <- rainfall %>%
  left_join(impact_data %>% dplyr::select(district, date, flood), by = c('district', 'date')) %>%
  left_join(glofas_data, by = c("district", "date"))
