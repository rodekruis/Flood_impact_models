library(raster)
library(sf)
library(tidyverse)
library(velox)
library(R.utils)

# Because velox$extract() does not take extra arguments we have to write a custom mean no na function
mean_no_na <- function(x) {
  mean(x, na.rm=T)
}

ethiopia_catchments <- st_read("shapes/catchments/ethiopia_admin3/ethiopia_admin3_catchments.shp")

raster_file_paths <- paste0("raw_data/chirps_full/", setdiff(list.files("raw_data/chirps_full/"), ".gitkeep"))
rainfall_dfs <- list()
for (raster_file_path in raster_file_paths) {
  print(paste0("Calculating raster ", raster_file_path, " time ", Sys.time()))
  file_date <- str_replace_all(gsub(".tif.gz", "", gsub(".*v2.0.", "", raster_file_path)), "\\.", "-")
  raster_file <- gunzip(raster_file_path, skip = TRUE, overwrite = TRUE, remove = FALSE)
  raster_file <- raster(raster_file)
  raster_velox <- velox(raster_file)
  rain_values <- raster_velox$extract(ethiopia_catchments, fun=mean_no_na)
  
  rainfall_df <- tibble(
    pcode = ethiopia_catchments$admin_id,
    date = file_date,
    swi = rain_values
  )
  
  write.csv(rainfall_df, paste0("raw_data/Ethiopia/rainfall/", file_date, ".csv"), row.names=F)
  
  rainfall_dfs[[file_date]] <- rainfall_df
}

 # Combining files
all_rainfall <- bind_rows(rainfall_dfs)
write.csv(all_rainfall, "raw_data/Ethiopia/rainfall/ethiopia_admin3_rainfall.csv", row.names=F)

swi005 <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi005.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric")) %>% rename(swi005 = swi)
swi010 <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi010.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric")) %>% rename(swi010 = swi)
swi015 <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi015.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric")) %>% rename(swi015 = swi)

swi_all <- swi005 %>% left_join(swi010) %>% left_join(swi015)
write.csv(swi_all, "raw_data/Ethiopia/swi/ethiopia_admin3_swi_all.csv", row.names=F)
