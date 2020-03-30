library(raster)
library(sf)
library(tidyverse)
library(velox)

# Because velox$extract() does not take extra arguments we have to write a custom mean no na function
mean_no_na <- function(x) {
  mean(x, na.rm=T)
}

ethiopia_catchments <- st_read("shapes/catchments/ethiopia_admin3/ethiopia_admin3_catchments.shp")
raster_folders <- setdiff(list.dirs("shapes/SWI/", full.names=F), "")
depth <- "015"

swi_dfs <- list()

for (raster_folder in raster_folders) {
  print(paste0("Calculating raster ", raster_folder, " time ", Sys.time()))
  filename <- paste0("shapes/SWI/", raster_folder, "/c_gls_SWI10-SWI-", depth, "_", raster_folder, "1200_CUSTOM_ASCAT_V3.1.1.tiff")
  swi_raster <- raster(filename)
  swi_velox <- velox(swi_raster)
  swi_values <- swi_velox$extract(ethiopia_catchments, fun=mean_no_na)
  
  swi_df <- tibble(
    pcode = ethiopia_catchments$admin_id,
    date = as.character(raster_folder),
    swi = swi_values
  )
  
  write.csv(swi_df, paste0("raw_data/Ethiopia/swi/", raster_folder, "_", depth, ".csv"), row.names=F)
  
  swi_dfs[[raster_folder]] <- swi_df
}

# Combining files
all_swis <- bind_rows(swi_dfs)
write.csv(all_swis, paste0("raw_data/Ethiopia/swi/ethiopia_admin3_swi", depth, ".csv"), row.names=F)

swi005 <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi005.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric")) %>% rename(swi005 = swi)
swi010 <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi010.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric")) %>% rename(swi010 = swi)
swi015 <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi015.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric")) %>% rename(swi015 = swi)

swi_all <- swi005 %>% left_join(swi010) %>% left_join(swi015)
write.csv(swi_all, "raw_data/Ethiopia/swi/ethiopia_admin3_swi_all.csv", row.names=F)
