# -------------------- Libs & Sources ------------------------
library(dplyr)


source('scripts/create_rain_data.R')


# -------------------- Settings -------------------------------

shapefile_path <- file.path("shapes", "uganda_catchment", "ug_cat.shp")
layer <- "ug_cat"
p_code_column <- "N___N___PC"  # The column in the shapefile containing the pcode

rainfile_path <- file.path("raw_data", "rainfall_catchment.csv")
produce_new_rainfall_csv <- FALSE
regions <- c()


# -------------------- Data Extracting -------------------------

# Option to (re)produce rainfall csv
if (produce_new_rainfall_csv) {
  extract_rain_data_for_shapes(shapefile_path, layer, rainfile_path)
}

rainfall <- read.csv(rainfile_path) %>%
  mutate(date = as_date(date))

# -------------------- Mutating, merging and aggregating -------
rainfall <- create_extra_rainfall_vars(rainfall)



# Link flood events

# Model
