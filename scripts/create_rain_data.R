# Rainfall data should be downloaded first with download_rain_data.py

## Extract rainfall per district of Uganda:  

# Define projection
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

# Define a clip
clip <- function(raster,shape) {
  raster_crop <- crop(raster,shape)
  raster_bsn <- mask(raster_crop,shape) 
  return(raster_bsn)}

# Working directory for uganda boundary to read districts
wshade <- readOGR("boundaries/districts.shp",layer = "districts") 

# Working directory for uganda boundary to read kenya boundary
cliper <- readOGR("boundaries/uga_admbnda_adm1_UBOS_v2.shp",layer = "uga_admbnda_adm1_UBOS_v2")

# Define similar projection

cliper <- spTransform(cliper, crs1)
wshade <- spTransform(wshade, crs1) 

# Load list of files 
setwd("~/GitHub/statistical_floodimpact_uganda/chirpstif")
ascii_data <- list.files(, pattern = ".tif.gz") #List tif files downloaded by the python code

# Clipe files to kenya boundary
xx <- stack()

# Read each ascii file to a raster and stack it to xx
for (files in ascii_data) {
  fn <- gunzip(files,skip = TRUE, overwrite = TRUE, remove = FALSE)
  r2 <- raster(fn)
  x1 <- clip(r2,cliper)
  xx <- stack( xx ,x1 )
  file.remove(fn)
}
# Remove noise from the data
xx[xx < 0] <- NA

# Extract data for each district / you can use different functions here 
arain <- raster::extract(x = xx,  y = wshade, fun = mean, df=TRUE)

write.table(arain, "raw_data/rain_data.txt")
