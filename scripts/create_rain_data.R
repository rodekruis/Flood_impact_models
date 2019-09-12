# Rainfall data should be downloaded first with download_rain_data.py
library(rgdal)
library(raster)
library(R.utils)
library(zoo)

# Used in create_stacked_rain_raster to clip to the shape of Uganda
clip <- function(raster, shape) {
  raster_crop <- crop(raster,shape)
  raster_bsn <- mask(raster_crop,shape)
  
  return(raster_bsn)
}

# Should really never be necessary to run again unless you e.g. want to load in new years of rain data
# And be carefull this will run very very long, if you are new to this project better ask for the grid file from a team member
create_stacked_rain_raster <- function(){
  # Define projection
  crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 
  
  # Working directory for uganda boundary to read kenya boundary
  cliper <- readOGR("boundaries/uga_admbnda_adm1_UBOS_v2.shp",layer = "uga_admbnda_adm1_UBOS_v2")
  cliper <- spTransform(cliper, crs1)
  
  # Load list of files 
  ascii_data <- list.files("raw_data/chirps", pattern = ".tif.gz") #List tif files downloaded by the python code
  
  # Clipe files to kenya boundary
  xx <- raster::stack()
  
  # Read each ascii file to a raster and stack it to xx
  for (files in ascii_data)  {
    fn <- gunzip(file.path("raw_data", "chirps", files), skip = TRUE, overwrite = TRUE, remove = FALSE)
    print(fn)
    r2 <- raster(fn)
    x1 <- clip(r2,cliper)
    xx <- raster::stack(xx, x1)
    file.remove(fn)
  }
  
  # Remove noise from the data
  xx[xx < 0] <- NA
  
  total_raster[total_raster < 0] <- NA
  
  writeRaster(total_raster, "processed_data/total_raster.grd", format="raster", overwrite = TRUE)
}

# Reads in the earlier produced raster and extracts rain data for specific shapes
# Writes the rainfall file to a csv file
extract_rain_data_for_shapes <- function(shapefile_path, layer, rainfile_name, use_large_split_files = TRUE){
  crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 
  
  # Usually the else method should work, but the raster is currently to big for the .grd structure 
  if (use_large_split_files) {
    load("processed_data/spat_data_20100215.Rdata")
    raster1 <- xx
    load("processed_data/spat_data_20100215_20190630.Rdata")
    raster2 <- xx
    total_raster <- stack(raster1, raster2)
  } else {
    total_raster <- stack("processed_data/total_raster.grd")    
  }
  
  wshade <- readOGR(shapefile_path, layer = layer)
  wshade <- spTransform(wshade, crs1)
  
  rainfall <- raster::extract(x = total_raster,  y = wshade, fun = mean, df = TRUE, na.rm = TRUE)
  
  rainfall['pcode'] <- wshade[[p_code_column]]
  
  colnames(rainfall) = gsub(pattern = "chirps.v2.0.", replacement = "", x = names(rainfall))
  rainfall <- rainfall %>%
    dplyr::select(-ID) %>% 
    gather("date", "rainfall", -pcode) %>%
    mutate(date = as_date(date))
  
  CRA <- read_excel("raw_data/CRA Oeganda.xlsx")
  rainfall <- rainfall %>%
    left_join(CRA %>% dplyr::select(name, pcode), by = "pcode") %>%
    rename(district = name) %>%
    mutate(district = toupper(district))
  
  write.csv(rainfall, rainfile_name, row.names = FALSE)
}

# Central location to create extra rainfall vars
# TODO make lag and moving avg options variable (but then also change in plot scripts)
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


