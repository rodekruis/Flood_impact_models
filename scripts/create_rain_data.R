# Rainfall data should be downloaded first with download_rain_data.py
library(rgdal)
library(raster)
library(R.utils)
library(zoo)
library(stringr)
library(tidyr)
library(dplyr)
library(lubridate)
source("settings.R")

# Used in create_stacked_rain_raster to clip to the shape of Uganda
clip <- function(raster, shape) {
  raster_crop <- crop(raster,shape)
  raster_bsn <- mask(raster_crop,shape)
  
  return(raster_bsn)
}

# Create .tif files of a country from .tif.gz files from whole of Africa
create_country_tifs <- function(country, country_settings, verbose=TRUE) {
  cliper <- readOGR(country_settings[[country]][["boundary_shape_path"]],
                    layer = country_settings[[country]][["boundary_layer_name"]])

  cliper <- spTransform(cliper, crs1)
  
  # Load list of files 
  filenames <- list.files("raw_data/chirps_full", pattern = ".tif.gz") #List tif files downloaded by the python code

  # Read each ascii file to a raster and stack it to xx
  for (filename in filenames)  {
    if (verbose) {
      print(paste("Processing", filename))      
    }
    fn <- gunzip(file.path("raw_data", "chirps_full", filename), skip = TRUE, overwrite = TRUE, remove = FALSE)
    raster_file <- raster(fn)
    clipped_raster <- clip(raster_file,cliper)
    new_filename <- str_sub(gsub('.tif.gz', '', filename), -10, -1)
    writeRaster(clipped_raster, paste0("raw_data/", country, "/chirps_tifs/", new_filename, '_rainfallraw.tif'), overwrite=TRUE)
    file.remove(fn)
  }
}

# Should really never be necessary to run again unless you e.g. want to load in new years of rain data
# And be carefull this will run very very long, if you are new to this project better ask for the grid file from a team member
create_yearly_raster_stacks <- function(country, country_settings, years=seq(1999, 2019)){
  # Creates a brick for each year since they can get too big to stack them all together
  for (year in years) {
    tif_files <- list.files(paste0("raw_data/", country, "/chirps_tifs"), pattern = as.character(year))
    tif_files <- paste0("raw_data/", country, "/chirps_tifs/", tif_files)
    all_rasters <- sapply(tif_files, raster)
    raster_brick <- brick(all_rasters)
    writeRaster(raster_brick,
                filename=file.path("raw_data", country, "chirps_bricks", paste0(year, "_brick.grd")),
                bandorder='BIL', overwrite=TRUE)
  }
}

# Reads in the earlier produced raster and extracts rain data for specific shapes
# Writes the rainfall file to a csv file
extract_rain_data_for_shapes <- function(country, country_settings, year_range=seq(1999, 2019)){
  years_rainfall <- list()
  for (year in year_range) {
    year_raster <- stack(file.path("raw_data", country, "chirps_bricks", paste0(year, "_brick.grd")))
    wshade <- readOGR(country_settings[[country]][["catchment_shape_path"]],
                      layer = country_settings[[country]][["catchment_layer_name"]])
    
    wshade <- spTransform(wshade, crs1)
    
    year_rainfall <- raster::extract(x = year_raster,  y = wshade, fun = mean, df = TRUE, na.rm = TRUE)
    
    id_column <- country_settings[[country]][["catchment_id_column"]]
    year_rainfall$id_column <- as.character(wshade[[id_column]])
    
    colnames(year_rainfall) = gsub(pattern = "chirps.v2.0.", replacement = "", x = names(year_rainfall))
    year_rainfall <- year_rainfall %>%
      dplyr::select(-ID) %>% 
      gather("date", "rainfall", -pcode) %>%
      mutate(date = as_date(date))
    
    years_rainfall[[year]] = year_rainfall
  }
  
  rainfall <- bind_rows(years_rainfall)
  write.csv(rainfall, file.path("raw_data", country, paste0("rainfall_", country, ".csv")), row.names = FALSE)
}

# Central location to create extra rainfall vars
create_extra_rainfall_vars <- function(rainfall, many_vars=FALSE, moving_avg=TRUE, anomaly=TRUE) {

  rainfall <- rainfall %>%
    dplyr::rename(zero_shifts = rainfall) %>%
    arrange(district, date) %>%
    mutate(
      zero_shifts = as.numeric(zero_shifts),
      one_shift = lag(zero_shifts, 1),
      two_shifts = lag(zero_shifts, 2),
      three_shifts = lag(zero_shifts, 3),
      rainfall_2days = zero_shifts + one_shift,
      rainfall_3days = rainfall_2days + two_shifts,
      rainfall_4days = rainfall_3days + three_shifts,
      rainfall_6days = rainfall_4days + lag(zero_shifts, 5),
      rainfall_9days = rainfall_6days + lag(zero_shifts, 7) + lag(zero_shifts, 8))
  
  if (many_vars) {
    rainfall <- rainfall %>%
      mutate(
        four_shifts = lag(zero_shifts, 4),
        five_shifts = lag(zero_shifts, 5),
        rainfall_5days = rainfall_4days + four_shifts)
  }

  if (moving_avg) {
    rainfall <- rainfall %>%
      mutate(
        moving_avg_3 = rollmean(one_shift, 3, fill = NA, align = "right"),
        moving_avg_5 = rollmean(one_shift, 5, fill = NA, align = "right")
      )
  }
  
  if (anomaly) {
    rainfall <- rainfall %>%
      mutate(
        anomaly_avg3 = zero_shifts - moving_avg_3,
        anomaly_avg5 = zero_shifts - moving_avg_5
      )
  }
  
  return(rainfall)
}

# Running the rainfall extraction is commented out because it will take a very long time and should only be done once

# create_country_tifs("uganda", country_settings)
# create_yearly_raster_stacks("uganda", country_settings)
# extract_rain_data_for_shapes("uganda", country_settings)