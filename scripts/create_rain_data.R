# Rainfall data should be downloaded first with download_rain_data.py
library(rgdal)
library(raster)
library(R.utils)


## Extract rainfall per district of Uganda:
catchment <- TRUE

# Define projection
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

# Define a clip
clip <- function(raster,shape) {
  raster_crop <- crop(raster,shape)
  raster_bsn <- mask(raster_crop,shape) 
  return(raster_bsn)
}

# Working directory for uganda boundary to read districts
if (catchment) {
  wshade <- readOGR(file.path("shapes", "uganda_catchment", "ug_cat.shp"),layer = "ug_cat")  
} else {
  wshade <- readOGR("boundaries/districts.shp",layer = "districts") 
}

# Working directory for uganda boundary to read kenya boundary
cliper <- readOGR("boundaries/uga_admbnda_adm1_UBOS_v2.shp",layer = "uga_admbnda_adm1_UBOS_v2")

# Define similar projection
cliper <- spTransform(cliper, crs1)
wshade <- spTransform(wshade, crs1) 

# Load list of files 
ascii_data <- list.files("raw_data/chirps", pattern = ".tif.gz") #List tif files downloaded by the python code

# Clipe files to kenya boundary
xx <- raster::stack()

# Read each ascii file to a raster and stack it to xx
for (files in ascii_data)  {
  fn <- gunzip(file.path("raw_data", "chirps", files),skip = TRUE, overwrite = TRUE, remove = FALSE)
  print(fn)
  r2 <- raster(fn)
  x1 <- clip(r2,cliper)
  xx <- raster::stack(xx, x1)
  file.remove(fn)
}

# Remove noise from the data
xx[xx < 0] <- NA

total_raster[total_raster < 0] <- NA

# Can be used to write the raster to a file for future use since it takes very long to build
# writeRaster(total_raster, "processed_data/total_raster.grd", format="raster", overwrite = TRUE)
# total_raster <- stack("processed_data/total_raster.grd")

# Extract data for each district / you can use different functions here 
arain <- raster::extract(x = total_raster,  y = wshade, fun = mean, df = TRUE, na.rm = TRUE)

if (catchment) {
  write.csv(arain, "raw_data/rainfall_catchment.csv", row.names = FALSE)
  write.table(arain, "raw_data/rainfall_catchment.txt")
} else {
  write.csv(arain, "raw_data/rainfall.csv", row.names = FALSE)
  write.table(arain, "raw_data/rainfall.txt")
}
