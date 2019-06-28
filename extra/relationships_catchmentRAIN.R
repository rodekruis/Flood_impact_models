#------------------------  Set working directory -------------------------------

# Set working directory to the folder where github files are stored: 
setwd("~/GitHub/statistical_floodimpact_uganda")

#------------------------  Load required packages ------------------------------

# Load required packages: 
require(raster)
require(rgdal)
require(ncdf4)
library(R.utils)
library(rgdal)
library(rlang)
library(tibble)
library(rgdal)
library(maps)
library(ncdf4)
library(reshape2)
library(rasterVis)
library(RColorBrewer)
library(plyr)
library(utils)
library(zoo)
library(dplyr)
library(readr)
library(utils)
library(readxl)
library(randomForest)
library(RFmarkerDetector)
library(AUCRF)
library(caret)
library(kernlab)
library(ROCR)
library(MASS)
library(glmnet)
library(pROC)
library(MLmetrics)
library(plyr)
library(psych)
library(corrplot)
library(visdat)
library(naniar)
library(tidyr)

#------------------------ Download rainfall data -------------------------------

## Copy the following script and run it in Python to download the rainfall data: 

# from ftplib import FTP 
# import os
# ftp = FTP('ftp.chg.ucsb.edu')
# ftp.login(user='', passwd = '')
# #ftp.cwd('/pub/org/chg/products/CHIRPS-2.0/global_daily/netcdf/p05/') 
# ftp.cwd('/pub/org/chg/products/CHIRPS-2.0/africa_daily/tifs/p05/')
# 
# pattern = '.tif.gz' # Replace with your target substring
# def downloadFiles1(destination):
#   filelist=ftp.nlst()
# 
# for file in filelist:
#   if pattern in file:
#   ftp.retrbinary("RETR "+file, open(os.path.join(destination,file),"wb").write)
# print (file + " downloaded")
# return
# dest="C:/Users/User/Documents/GitHub/statistical_floodimpact_uganda/chirpstif" 
# downloadFiles1(dest)
# ftp.quit()

#----------------- Extract rainfall per catchment area -------------------------

# Define projection
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

# Define a clip
clip <- function(raster,shape) {
  raster_crop<-crop(raster,shape)## masking to basin box 
  raster_bsn<-mask(raster_crop,shape) # to bsn boundary only
  return (raster_bsn)}

# Working directory for uganda boundary to read districts
wshade<-readOGR("boundaries/uganda_catchments.shp",layer="uganda_catchments") 

# Working directory for uganda boundary to read kenya boundary
cliper<-readOGR("boundaries/uga_admbnda_adm1_UBOS_v2.shp",layer="uga_admbnda_adm1_UBOS_v2")

# Define similar projection
cliper<- spTransform(cliper, crs1)
wshade<- spTransform(wshade, crs1) 

# Load list of files 
setwd("~/GitHub/statistical_floodimpact_uganda/chirpstif")
ascii_data <- list.files(,pattern=".tif.gz") #List tif files downloaded by the python code

# Clipe files to kenya boundary
xx<-stack()

# Read each ascii file to a raster and stack it to xx
for(files in ascii_data){
  #fn<-gunzip(files,skip=TRUE, overwrite=TRUE, remove=TRUE)
  #fn <- file.path("C:/chirpstif/", paste0(files))
  fn<-gunzip(files,skip=TRUE, overwrite=TRUE, remove=FALSE)
  r2<-raster(fn)
  x1<-clip(r2,cliper)
  xx <- stack( xx ,x1 )
  file.remove(fn)
}

# Remove noise from the data
xx[xx<0] <- NA

# Extract data for each catchment area / you can use different functions here 
arain <- raster::extract(x = xx,  y = wshade, fun = mean, df=TRUE) 

setwd("~/GitHub/statistical_floodimpact_uganda")

#---------------------- Load in rainfall dataset -------------------------------

# Load in rainfall dataset 
rainfall <- read.delim("extra/raw data/rainfall_catchment.txt")

#---------------------- Load in Desinventar dataset ----------------------------

# Load in Desinventar dataset: 
DI_uga <- read_csv("raw data/DI_uga.csv")

#------------------------ Load in  CRA dataset ---------------------------------

#Load in Community Risk Assessment dataset: 
CRA <- read_excel("raw data/CRA Oeganda.xlsx")

#------------------- Prepare rainfall dataset for merging-----------------------

# Define projection: 
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

# Working directory for uganda boundary to read districts: 
wshade<-readOGR("boundaries/uganda_catchments.shp",layer="uganda_catchments") 

# Define similar projection: 
wshade <- spTransform(wshade, crs1)

# Area in km2: 
area_uganda <- read.csv("extra/raw data/area_uganda.csv")

area_total <- area_uganda %>%
  group_by(ADM1_EN) %>% 
  transmute(total=sum(area))

area <- as.data.frame(area_uganda$area)
area_total <- as.data.frame(area_total$total)

# Put the overlap in the rainfall dataset: 
district <- as.data.frame(wshade@data[["ADM1_EN"]])
rainfall <- cbind(rainfall, district, area, area_total)

rainfall$weight <- rainfall$`area_uganda$area`/rainfall$`area_total$total`

# Remove ID from dataset (because now we have district instead): 
rainfall$ID <- NULL

# Name the column of the districtnames "ID": 
colnames(rainfall)[c(4384:4387)] <- c("district", "area", "areatotal", "weight") #deze kolomnummers veranderen in de 4 laatste kolommen! 

# Move 'ID' variable to front of dataset: 
rainfall <- dplyr::select(rainfall, c("district", "area", "areatotal", "weight"), everything())

# Remove "chirps.v2.0" from date: 
colnames(rainfall) = gsub(pattern = "chirps.v2.0.", replacement = "", x = names(rainfall))

# Weight the rainfall by the overlap: 
rainfall[5:4387] <- rainfall$weight*rainfall[5:4387] #het laatste nummer veranderen in de laatste kolomnummer! 

# Sum all rainfall within 1 district: 
rainfall <- rainfall %>%
  group_by(district) %>% 
  summarise_all(funs(mean), na.rm = TRUE)

# Remove overlap from dataset: 
rainfall$area <- NULL
rainfall$areatotal <- NULL
rainfall$weight <- NULL

# Transpose the matrix: 
rainfall <- as.data.frame(t(rainfall))

# Make the district names header: 
colnames(rainfall) <- as.character(unlist(rainfall[1,]))
rainfall <- rainfall[-1, ]

# Make a column with the dates:  
rainfall <- cbind(rownames(rainfall), data.frame(rainfall, row.names=NULL))
colnames(rainfall)[1] <- "date"

# Make the date as.Date instead of a factor:
rainfall$date <- as.Date(rainfall$date, format = "%Y.%m.%d")

# Reshaping wide format to long format: 
rainfall <- rainfall %>% gather(district, rainfall, MOYO:SOROTI)

# Make the numeric variables as.numeric: 
rainfall[3] <- data.frame(lapply(rainfall[3], function(x) as.numeric(as.character(x))))

# Make empty columns to fill in later: 
names(rainfall)[3] <- "zero_shifts"
rainfall$one_shift <- NA
rainfall$two_shifts <- NA
rainfall$three_shifts <- NA
rainfall$four_shifts <- NA
rainfall$five_shifts <- NA 

# Create 4 extra rainfall variables which represent the cumulative rainfall of 2 up to 5 days: 
rainfall[2:13149,4] <- rainfall[1:13148, 3]
rainfall$rainfall_2days <- rainfall$zero_shifts + rainfall$one_shift
rainfall[3:13149,5] <- rainfall[1:13147, 3]
rainfall$rainfall_3days <- rainfall$zero_shifts + rainfall$one_shift + rainfall$two_shifts
rainfall[4:13149,6] <- rainfall[1:13146, 3]
rainfall$rainfall_4days <- rainfall$zero_shifts + rainfall$one_shift + rainfall$two_shifts + rainfall$three_shifts
rainfall[5:13149,7] <- rainfall[1:13145, 3]
rainfall$rainfall_5days <- rainfall$zero_shifts + rainfall$one_shift + rainfall$two_shifts + rainfall$three_shifts + rainfall$four_shifts
rainfall[6:13149,8] <- rainfall[1:13144, 3]

#----------------------- Prepare Desinventar dataset for merging----------------

# Select only the rows which are flood related: 
DI_uga <- subset(DI_uga, event == "FLOOD")

# Rename first column "district" (needed to merge all datasets together):
colnames(DI_uga)[5] <- "district"

# Select only the rows with year equal or above 2000: 
DI_uga <- filter(DI_uga, year >= 2000) 

# Put the year, month and day of the flood together with a dash between them and call this column date: 
DI_uga$date <- paste(DI_uga$year,DI_uga$month,DI_uga$day,sep="-")

# Make date as.Date instead of a character: 
DI_uga$date <- as.Date(DI_uga$date)

# Order dataset based on district and date: 
DI_uga <- DI_uga[order(DI_uga$district, DI_uga$year, DI_uga$month, DI_uga$day),]

# Fill in the expected dates of the NA's by comparing the flood-date with the rainfall data:  
DI_uga[1,23] <- as.Date("2007-07-30")
DI_uga[5:8,23] <- as.Date("2012-07-23")
DI_uga[12,23] <- as.Date("2007-07-30")
DI_uga[16,23] <- as.Date("2012-11-28")
DI_uga[17:36,23] <- as.Date("2013-10-09")
DI_uga[43,23] <- as.Date("2007-07-30")
DI_uga[44,23] <- as.Date("2007-09-07")
DI_uga[51:53,23] <- as.Date("2013-05-07")
DI_uga[62,23] <- as.Date("2007-07-30")
DI_uga[63:69,23] <- as.Date("2007-07-30")
DI_uga[70:75,23] <- as.Date("2007-08-10")
DI_uga[83:84,23] <- as.Date("2007-09-09")
DI_uga[86,23] <- as.Date("2007-10-22")
DI_uga[88,23] <- as.Date("2008-08-15")
DI_uga[97:102,23] <- as.Date("2012-08-27")
DI_uga[121,23] <- as.Date("2007-07-29")
DI_uga[125,23] <- as.Date("2007-07-30")
DI_uga[126,23] <- as.Date("2007-09-07")
DI_uga[137:138,23] <- as.Date("2013-01-30")
DI_uga[145:146,23] <- as.Date("2007-07-30")
DI_uga[147:148,23] <- as.Date("2007-10-22")
DI_uga[159,23] <- as.Date("2010-10-23")
DI_uga[160,23] <- as.Date("2012-12-29")
DI_uga[163,23] <- as.Date("2013-10-29")
DI_uga[174,23] <- as.Date("2018-03-19")  
DI_uga[180:181,23] <- as.Date("2005-06-28")
DI_uga[182,23] <- as.Date("2007-07-30")
DI_uga[183,23] <- as.Date("2007-09-09")
DI_uga[187:197,23] <- as.Date("2012-09-02")
DI_uga[223,23] <- as.Date("2013-03-19")
DI_uga[234,23] <- as.Date("2013-05-05")
DI_uga[242,23] <- as.Date("2002-04-11")
DI_uga[262:269,23] <- as.Date("2010-02-16")
DI_uga[278:279,23] <- as.Date("2011-02-03")
DI_uga[280,23] <- as.Date("2011-07-29")
DI_uga[306,23] <- as.Date("2018-04-04")
DI_uga[330,23] <- as.Date("2013-04-11")
DI_uga[332,23] <- as.Date("2007-09-05")
DI_uga[335,23] <- as.Date("2007-07-03")
DI_uga[336,23] <- as.Date("2007-07-03")
DI_uga[337,23] <- as.Date("2007-09-02")
DI_uga[340:343,23] <- as.Date("2013-09-01")
DI_uga[349,23] <- as.Date("2014-09-05")
DI_uga[364,23] <- as.Date("2013-03-01") # no rainfall data 
DI_uga[366,23] <- as.Date("2014-04-01") # no rainfall data  
DI_uga[373,23] <- as.Date("2007-07-01") # no rainfall data 
DI_uga[375,23] <- as.Date("2012-01-01") # no rainfall data 
DI_uga[376,23] <- as.Date("2012-01-01") # no rainfall data 
DI_uga[377:385,23] <- as.Date("2012-04-01") # no rainfall data 
DI_uga[386:387,23] <- as.Date("2012-06-01") # no rainfall data 
DI_uga[388,23] <- as.Date("2013-04-01") # no rainfall data 
DI_uga[389:395,23] <- as.Date("2013-06-01") # no rainfall data 
DI_uga[399:401,23] <- as.Date("2010-01-01") # no rainfall data 
DI_uga[414,23] <- as.Date("2014-09-01") # no rainfall data 
DI_uga[454,23] <- as.Date("2012-08-09")
DI_uga[455:457,23] <- as.Date("2012-09-02")
DI_uga[459,23] <- as.Date("2014-03-12") 
DI_uga[497,23] <- as.Date("2012-04-16")
DI_uga[503,23] <- as.Date("2013-04-12")
DI_uga[518:520,23] <- as.Date("2013-08-16")
DI_uga[521:523,23] <- as.Date("2013-04-11")
DI_uga[529,23] <- as.Date("2013-09-26")
DI_uga[537,23] <- as.Date("2007-07-30")
DI_uga[538:539,23] <- as.Date("2007-09-09")
DI_uga[541,23] <- as.Date("2010-04-22")
DI_uga[556:557,23] <- as.Date("2013-10-09")
DI_uga[558,23] <- as.Date("2013-03-30")
DI_uga[559:561,23] <- as.Date("2013-05-01")
DI_uga[566,23] <- as.Date("2013-08-16")
DI_uga[590,23] <- as.Date("2007-01-30")
DI_uga[591:595,23] <- as.Date("2007-07-30")
DI_uga[596:598,23] <- as.Date("2007-08-01")
DI_uga[607,23] <- as.Date("2007-09-09")
DI_uga[636,23] <- as.Date("2012-08-27")
DI_uga[638:644,23] <- as.Date("2012-09-02")
DI_uga[667,23] <- as.Date("2018-04-15")  
DI_uga[696:707,23] <- as.Date("2002-04-04")
DI_uga[708:712,23] <- as.Date("2010-02-16")
DI_uga[713:715,23] <- as.Date("2010-04-17")
DI_uga[720,23] <- as.Date("2013-04-11")
DI_uga[777,23] <- as.Date("2007-07-29")
DI_uga[778,23] <- as.Date("2007-09-11")
DI_uga[785:786,23] <- as.Date("2013-05-06")
DI_uga[794,23] <- as.Date("2006-12-30")
DI_uga[796,23] <- as.Date("2007-07-30")
DI_uga[799:804,23] <- as.Date("2012-07-25")
DI_uga[805:806,23] <- as.Date("2013-05-06")
DI_uga[808,23] <- as.Date("2007-07-30")
DI_uga[825,23] <- as.Date("2007-07-29")
DI_uga[826,23] <- as.Date("2013-09-04")
DI_uga[830,23] <- as.Date("2007-07-30")
DI_uga[832,23] <- as.Date("2007-09-05")
DI_uga[841:843,23] <- as.Date("2013-09-09")
DI_uga[847:848,23] <- as.Date("2013-04-12")
DI_uga[851:856,23] <- as.Date("2007-07-30")
DI_uga[858,23] <- as.Date("2010-02-16")
DI_uga[894,23] <- as.Date("2009-05-12")
DI_uga[903,23] <- as.Date("2013-04-12")
DI_uga[910,23] <- as.Date("2010-02-16")
DI_uga[930,23] <- as.Date("2007-07-30")
DI_uga[941:946,23] <- as.Date("2012-07-25")
DI_uga[964,23] <- as.Date("2011-02-01") # no rainfall data 
DI_uga[980:981,23] <- as.Date("2007-09-04")
DI_uga[1000,23] <- as.Date("2007-07-30")
DI_uga[1006:1012,23] <- as.Date("2012-07-23")
DI_uga[1014:1015,23] <- as.Date("2013-05-06")
DI_uga[1020,23] <- as.Date("2013-04-11")
DI_uga[1030:1033,23] <- as.Date("2012-07-25")
DI_uga[1034,23] <- as.Date("2012-09-02")
DI_uga[1035:1036,23] <- as.Date("2013-03-26")
DI_uga[1038:1041,23] <- as.Date("2013-05-06")
DI_uga[1045,23] <- as.Date("2007-08-03")
DI_uga[1056,23] <- as.Date("2012-04-15")
DI_uga[1080:1081,23] <- as.Date("2010-01-01") # no rainfall data 
DI_uga[1090:1096,23] <- as.Date("2012-05-01") # no rainfall data 
DI_uga[1101,23] <- as.Date("2013-05-01") # no rainfall data 
DI_uga[1113,23] <- as.Date("2007-07-30")
DI_uga[1114,23] <- as.Date("2007-07-30")
DI_uga[1116,23] <- as.Date("2012-04-18")
DI_uga[1120:1123,23] <- as.Date("2012-09-02")
DI_uga[1125,23] <- as.Date("2013-09-01")
DI_uga[1126,23] <- as.Date("2007-07-30")
DI_uga[1128,23] <- as.Date("2007-07-30")
DI_uga[1132,23] <- as.Date("2018-03-18") 
DI_uga[1135,23] <- as.Date("2012-04-07")
DI_uga[1147:1156,23] <- as.Date("2012-09-02")
DI_uga[1159,23] <- as.Date("2013-09-24")
DI_uga[1164,23] <- as.Date("2007-07-30")
DI_uga[1168:1177,23] <- as.Date("2007-09-28")
DI_uga[1199:1200,23] <- as.Date("2013-11-10")
DI_uga[1233,23] <- as.Date("2012-08-27")
DI_uga[1236,23] <- as.Date("2013-05-06")
DI_uga[1237:1241,23] <- as.Date("2013-09-02")
DI_uga[1292:1294,23] <- as.Date("2013-04-13")
DI_uga[1295,23] <- as.Date("2013-09-26")
DI_uga[1310,23] <- as.Date("2012-04-15")

# # The code I used to fill in the expected dates of the NA's by comparing the flood-date with the rainfall data:  
# test <- rainfall %>% filter(district == "ABIM", date >= "2011-03-01", date <= "2011-05-30")
# which.max(test$rainfall)

#-------------------- Prepare CRA dataset for merging --------------------------

# Make the districtnames uppercase (is needed to merge all datafiles together): 
CRA <- as.data.frame(sapply(CRA, toupper))

# Rename first column "district" (needed to merge all datasets together): 
colnames(CRA)[1] <- "district"

# Make the numeric variables as.numeric: 
CRA[4:56] <- data.frame(lapply(CRA[4:56], function(x) as.numeric(as.character(x))))

#------------------ Merge the three datasets -----------------------------------

# Merge the three datasets based on district and flooddate: 
data <- merge(DI_uga, rainfall, by = c('district', 'date'), is.na = FALSE)
data <- merge(data, CRA, by = 'district')
data <- data.frame(data, check.names = TRUE)

##--------------------------- Aggregate floods ----------------------------------

# Make extra column which represents the difference in date per district:  
data$difference <- NA
for (j in 1:nrow(data)) {
  data$difference[j] <- difftime(data$date[j + 1], data$date[j], units = "days")
} 

# If difference between two dates of same district is bigger than 7 (1 week),  
# use the reported date: 
data$date_NA <- data$date
for(i in 1:nrow(data)) { 
  if(data$difference[i] > 7 || data$difference[i] < 0 || is.na(data$difference[i])) { 
    data$date_NA[i] <- data$date[i] 
  } 
  # If difference between two dates of same district is smaller than 7 (1 week),  
  # set date to NA: 
  else { 
    data$date_NA[i] <- NA}
} 

# Set the dates with NA equal to the first known date of the district: 
data$date_NA_filled <- na.locf(data$date_NA, fromLast = TRUE)

# Move pcode to the front of the dataset: 
data <- dplyr::select(data, "pcode", everything())

# Remove some variables which I can't aggregate (as they are characters) and don't have to use anymore: 
data <- dplyr::select(data, -c("serial", "date", "admin_level_0_code", "admin_level_1_code", "admin_level_2_code", 
                               "admin_level_1_name", "admin_level_2_name", "event", "location", "sources", 
                               "year", "month", "day", "cause", "magnitude", "latitude", "longitude", 
                               "comments", "others", "pcode_parent", "difference", "date_NA", "pcode_level2"))

# Aggregate the floods in a district which have the same date (mean of filled columns):  
data_agg_c <- data %>%
  group_by(district, date_NA_filled) %>% 
  summarise_all(funs(mean), na.rm = TRUE)

# Make date as.Date:
data_agg_c$date_NA_filled <- as.Date(data_agg_c$date_NA_filled)

#---------------------------Rename and define all variables---------------------

# Remove variables which have 0-10 in name (highly correlated variables):  
data_agg_c <- dplyr::select(data_agg_c, -c(Violent.incidents.last.year..0.10., 
                                       Drought.exposure..0.10., Earthquake.exposure..0.10., Flood.exposure..0.10., 
                                       X..persons.with.disability..0.10., X..employed..0.10., X..Literacy..0.10., X..having.mosquito.nets..0.10., 
                                       X..of.orphans.under.18..0.10., Poverty.incidence..0.10., X..permanent.roof.type..0.10., X..Subsistence.farming..0.10., 
                                       X..permanent.wall.type..0.10., X..Access.to.safe.drinking.water..0.10., Nr..of.educational.facilities.per.10.000.people..0.10., 
                                       X..Access.to.electricity..0.10., Nr..of.health.facilities.per.10.000.people..0.10., X..Access.improved.sanitation..0.10.,
                                       Travel.time.to.nearest.city..0.10., X..with.internet.access..0.10., X..with.mobile.access..0.10.))

data_agg_c <- data_agg_c %>%
  mutate(GEN_pcode = pcode, 
         GEN_district = district, 
         GEN_date = date_NA_filled, 
         DI_people_deaths = deaths, 
         DI_people_injured = injured, 
         DI_people_missing = missing, 
         DI_people_affected = affected, 
         DI_houses_houses_destroyed = houses_destroyed, 
         DI_houses_houses_damaged = houses_damaged, 
         DI_economic_losses_loc = losses..loc, 
         DI_economic_losses_usd = losses..usd, 
         DI_infra_health = health, 
         DI_infra_education = education, 
         DI_economic_agriculture = agriculture, 
         DI_infra_industry = industry, 
         DI_infra_aqueduct = aqueduct, 
         DI_infra_sewerage = sewerage, 
         DI_infra_energy = energy, 
         DI_infra_communication = communication, 
         DI_infra_damaged_roads =  damaged.roads, 
         DI_infra_damaged_hospitals = damaged.hospitals, 
         DI_infra_damaged_education_centers = damaged.education.centers,
         DI_economic_damaged_crops = damage.in.crops.Ha., 
         DI_economic_lost_cattle = lost.cattle, 
         DI_people_evacuated = evacuated, 
         DI_people_relocated = relocated, 
         RAIN_at_day = zero_shifts, 
         RAIN_1day_before = one_shift, 
         RAIN_2days_before = two_shifts, 
         RAIN_3days_before = three_shifts, 
         RAIN_4days_before = four_shifts, 
         RAIN_5days_before = five_shifts, 
         RAIN_1day_before_cumulative = rainfall_2days, 
         RAIN_2days_before_cumulative = rainfall_3days, 
         RAIN_3days_before_cumulative = rainfall_4days, 
         RAIN_4days_before_cumulative = rainfall_5days, 
         CRA_hazard_violent_incidents = Violent.incidents.last.year, 
         CRA_vulnerability_disability = X..persons.with.disability, 
         CRA_coping_drinking_water = X..Access.to.safe.drinking.water, 
         CRA_coping_educational_facilities= Nr..of.educational.facilities.per.10.000.people, 
         CRA_coping_electricity = X..Access.to.electricity, 
         CRA_vulnerability_employed = X..employed, 
         CRA_hazard_drought_exposure = Drought.exposure, 
         CRA_hazard_earthquake_exposure = Earthquake.exposure, 
         CRA_hazard_flood_exposure = Flood.exposure, 
         CRA_coping_health_facilities = Nr..of.health.facilities.per.10.000.people, 
         CRA_coping_sanitation = X..Access.improved.sanitation, 
         CRA_vulnerability_literacy = X..Literacy, 
         CRA_vulnerability_mosquito_nets = X..having.mosquito.nets, 
         CRA_vulnerability_orphans = X..of.orphans.under.18, 
         CRA_vulnerability_poverty = Poverty.incidence, 
         CRA_vulnerability_roof_type = X..permanent.roof.type, 
         CRA_vulnerability_subsistence_farming = X..Subsistence.farming, 
         CRA_coping_time_to_city =  Travel.time.to.nearest.city, 
         CRA_vulnerability_wall_type = X..permanent.wall.type, 
         CRA_coping_internet_access = X..with.internet.access, 
         CRA_coping_mobile_access =  X..with.mobile.access, 
         CRA_general_land_area = Land.area, 
         CRA_general_displaced_persons = X..of.displaced.persons, 
         CRA_general_displaced_local_population = X..of.displaced...local.population, 
         CRA_general_elevation = Average.elevation, 
         CRA_general_population_density = Population.density, 
         CRA_general_population = Population,
         CRA_general_coping = Lack.of.Coping.Capacity,
         CRA_general_risk = Risk.score,
         CRA_general_hazard = Hazards.exposure,
         CRA_general_vulnerability = Vulnerability) %>%
  ungroup() %>%
  dplyr::select(GEN_pcode, 
                GEN_district, 
                GEN_date, 
                DI_people_deaths, 
                DI_people_injured, 
                DI_people_missing, 
                DI_people_affected, 
                DI_houses_houses_destroyed, 
                DI_houses_houses_damaged, 
                DI_economic_losses_loc, 
                DI_economic_losses_usd, 
                DI_infra_health, 
                DI_infra_education, 
                DI_economic_agriculture, 
                DI_infra_industry, 
                DI_infra_aqueduct, 
                DI_infra_sewerage, 
                DI_infra_energy, 
                DI_infra_communication, 
                DI_infra_damaged_roads, 
                DI_infra_damaged_hospitals, 
                DI_infra_damaged_education_centers,
                DI_economic_damaged_crops, 
                DI_economic_lost_cattle, 
                DI_people_evacuated, 
                DI_people_relocated, 
                RAIN_at_day, 
                RAIN_1day_before, 
                RAIN_2days_before, 
                RAIN_3days_before, 
                RAIN_4days_before, 
                RAIN_5days_before, 
                RAIN_at_day, 
                RAIN_1day_before_cumulative, 
                RAIN_2days_before_cumulative, 
                RAIN_3days_before_cumulative, 
                RAIN_4days_before_cumulative, 
                CRA_hazard_violent_incidents, 
                CRA_vulnerability_disability, 
                CRA_coping_drinking_water, 
                CRA_coping_educational_facilities, 
                CRA_coping_electricity, 
                CRA_vulnerability_employed, 
                CRA_hazard_drought_exposure, 
                CRA_hazard_earthquake_exposure, 
                CRA_hazard_flood_exposure, 
                CRA_coping_health_facilities, 
                CRA_coping_sanitation, 
                CRA_vulnerability_literacy, 
                CRA_vulnerability_mosquito_nets, 
                CRA_vulnerability_orphans, 
                CRA_vulnerability_poverty, 
                CRA_vulnerability_roof_type, 
                CRA_vulnerability_subsistence_farming, 
                CRA_coping_time_to_city, 
                CRA_vulnerability_wall_type, 
                CRA_coping_internet_access, 
                CRA_coping_mobile_access, 
                CRA_general_land_area, 
                CRA_general_displaced_persons, 
                CRA_general_displaced_local_population, 
                CRA_general_elevation, 
                CRA_general_population_density, 
                CRA_general_population,
                CRA_general_coping,
                CRA_general_risk,
                CRA_general_hazard, 
                CRA_general_vulnerability)

#--------------------- Prepare final dataset with 3 districts ------------------

# Seperate dataframe into dependent and independent variables:
data_agg_c_dep <- data_agg_c[c(1:3, 4:26)]
data_agg_c_indep <- data_agg_c[c(1:3, 27:36)]

# Make all values on dependent variables absolute:
data_agg_c_dep[4:26] <- abs(data_agg_c_dep[4:26])

# If value on dependent variables is above 0.5 make it a 1, otherwise a 0:
data_agg_c_dep[4:26][data_agg_c_dep[4:26] > 0.01] <- 1
data_agg_c_dep[4:26][data_agg_c_dep[4:26] <= 0.01] <- 0

# # Correlations between dependent variables:
# correlations <- round(cor(data_agg_c_dep[,4:26]),2)
# corrplot(correlations)

# I decided to only take the 9 binary variables into account when creating the impact variable 
data_agg_c_dep <- data_agg_c_dep[c(1:3, 12:20)]

# sum all the dependent variable values together: 
data_agg_c_dep$DEP_total_affect <- rowSums(data_agg_c_dep[4:12])

# Make total affect variable binary:
data_agg_c_dep$DEP_total_affect_binary[data_agg_c_dep$DEP_total_affect >= 1] <- 1
data_agg_c_dep$DEP_total_affect_binary[data_agg_c_dep$DEP_total_affect < 1] <- 0

# Bind dependent variables to independent variables: 
data <- cbind(data_agg_c_dep$DEP_total_affect_binary, data_agg_c_indep)
colnames(data)[1] <- "DEP_total_affect_binary"

# Make the created binary variables as factor: 
data$DEP_total_affect_binary <- as.factor(data$DEP_total_affect_binary)

# # Vizualize missingness:
# vis_miss(data)
# gg_miss_var(data)

# Do mean imputation for every remaining column that has a missing value:
for(i in 1:ncol(data)) {
  data[,i][is.na(data[,i])] <- mean(as.numeric(data[,i]), na.rm = TRUE)
}

# Remove unimportant variables:
data <- dplyr::select(data, -c(RAIN_1day_before, RAIN_2days_before, RAIN_3days_before, RAIN_4days_before, 
                               RAIN_5days_before))

# Write data to a file so not every time all the above steps have to be taken:
# setwd("~/GitHub/statistical_floodimpact_uganda/extra")
# write.table(data,file="data_catchmentRAIN.txt",sep="\t",row.names = T,col.names = T)
# setwd("~/GitHub/statistical_floodimpact_uganda")
data <- read.delim("extra/processed data/data_catchmentRAIN.txt")
data$DEP_total_affect_binary <- as.factor(data$DEP_total_affect_binary)

#------------- Relationships total impact vs. each RAIN predictor --------------

par(mfrow=c(2,5))
# Conditional density plots of total impact vs each RAIN variable: 
for (i in 5:9) {
  cdplot(DEP_total_affect_binary ~ data[,i], data = data, main = names(data[i]), xlab= names(data[i]))
}

# Scatterplots of total impact vs each RAIN variable: 
for (i in 5:9) {
  plot(data[,i], data$DEP_total_affect_binary, xlab= names(data[i]))
  fit <- glm(DEP_total_affect_binary ~ data[,i], data = data, family = "binomial")
  abline(fit)
}

# Correlations between total impact and RAIN variables: 
data$DEP_total_affect_binary <- as.numeric(data$DEP_total_affect_binary)
correlations <- round(cor(data[,c(1,5:9)]),2)
corrplot(correlations)

