library(lubridate)
library(stringr)
library(plyr)
library(dplyr)
library(rgdal)
library(raster)
library(R.utils)
library(tidyr)


# right characters
right = function(text, num_char) {
  substr(text, nchar(text) - (num_char-1), nchar(text))
}

# Prepare the cliper
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 
cliper <- readOGR("shapes/uga_admbnda_adm1/uga_admbnda_adm1_UBOS_v2.shp",layer = "uga_admbnda_adm1_UBOS_v2")
cliper <- spTransform(cliper, crs1)

# Make a grid of dates
dates = tibble(date = seq(ymd('2000-01-01'), ymd('2000-12-31'), by = '1 day'))

dates <- dates %>%
  mutate(month = str_pad(month(date), 2, side="left", "0"),
         day = str_pad(day(date), 2, side="left", "0"),
         filepart_avg = paste(month, day, 'tif', sep = "."))

filenames = list.files('raw_data/uganda/chirps_tifs')
filenames = sapply(filenames, function(x) paste0('raw_data/uganda/chirps_tifs/', x), USE.NAMES=FALSE)

# Loop over all days
for (date_substr in dates$filepart[305:366]){
  print(paste0('Calculating average of: ', date_substr))
  filenames_sub <- filenames[grep(date_substr, filenames)]
  
  day_stack <- raster::stack()

  # Loop over all files related to this date, clip the raster and stack them up
  for (filename in filenames_sub){
    rain_file <- gunzip(filename, skip = TRUE, overwrite = TRUE, remove = FALSE)
    raster <- raster(rain_file)
    clipped_raster <- clip(raster, cliper)
    day_stack <- raster::stack(day_stack, clipped_raster)
    
    new_filename <- str_sub(gsub('.tif.gz', '', filename), -10, -1)
    writeRaster(clipped_raster, paste0("raw_data/uganda/chirps_tifs/", new_filename, '_rainfallraw.tif'), overwrite=TRUE)    
    
    file.remove(rain_file)
  }  
  # Remove noise from the data
  day_stack[day_stack < 0] <- NA
  avg_day_stack <- mean(day_stack, na.rm=T)

  
  writeRaster(day_stack, paste0("raw_data/uganda/chirps_dayaverages/", date_substr), overwrite = TRUE)
}



for (filepart_avg in dates$filepart_avg){
  print(paste0('Calculating anomalies of group: ', filepart_avg))
  filepart_raw <- gsub('.tif', '_rainfallraw.tif', filepart_avg)
  filenames_sub <- filenames[grep(filepart_raw, filenames)]

  day_avg_raster <- raster(paste0("raw_data/uganda/chirps_dayaverages/", filepart_avg))  
  
  
  # Loop over all files related to this date, clip the raster and stack them up
  for (filename in filenames_sub){

    # day_file <- gunzip(filename, skip = TRUE, overwrite = TRUE, remove = FALSE)
    raster <- raster(filename)
    clipped_raster <- clip(raster, cliper)
    anomaly_raster <- clipped_raster - day_avg_raster
    
    new_filename <- str_sub(gsub('_rainfallraw.tif', '', filename), -10, -1)
    writeRaster(anomaly_raster, paste0("raw_data/uganda/chirps_anomalies/", new_filename, '_anomaly.tif'), overwrite = TRUE)
  }
}

quantile95 <- function(x, na.rm = TRUE){
  quantile(x, probs=0.95, na.rm=na.rm)
}

shapefile_path <- file.path("shapes", "uganda_catchment", "ug_cat.shp")
layer <- "ug_cat"

crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

wshade <- readOGR(shapefile_path, layer = layer)
wshade <- spTransform(wshade, crs1)
wshade2 <- wshade[wshade@data$N___N___PC == "21UGA013005",]

raster_stack <- sapply(paste0('raw_data/uganda/chirps_anomalies/', list.files('raw_data/uganda/chirps_anomalies')), raster)
raster_stack <- raster::stack(raster_stack)

rainfall <- raster::extract(x = raster_stack,  y = wshade2, fun = quantile95, df = TRUE, na.rm = TRUE)
save(rainfall, file="rainfall_test.rda")

rainfall['pcode'] <- "21UGA013005"

colnames(rainfall) = substring(names(rainfall), 2)


rainfall2 <- rainfall %>%
  # dplyr::select(-ID) %>% 
  gather("date", "rainfall", -pcode) %>%
  mutate(date = as_date(date))

rainfall2$district = "Katakwi"

write.csv(rainfall2, 'raw_data/uganda/rainfall_anomaly_katakwi.csv', row.names = FALSE)

