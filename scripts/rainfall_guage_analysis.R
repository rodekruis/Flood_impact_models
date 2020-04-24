library(tidyverse)
library(sp)
library(dplyr)
library(ggplot2)
library(tidyr)
library(purrr)
library(stringr)
library(tmap)
library(maps)
library(httr)
library(sf)
library(ncdf4)
library(httr)
library(zoo)
library(ggpubr)
#---------------------- setting -------------------------------
Country="Ethiopia"
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

source("Geo_settings.R")
setwd('../')
settings <- country_settings
url<- parse_url(url_geonode)

#----------------------------function defination -------------

make_zoomed_in_plots <- function(impact_zone,impact_data,hazard,t_delta=30,pdf_name){
  pdf(pdf_name, width=11, height=8.5)
  
  impact_data<- impact_data %>% mutate(Date_=as.Date(Date,format="%d/%m/%Y"))
  for (i in 1:nrow(impact_data)) {
    # Get data from row
    flood_date <- impact_data[i, ]$Date_
    district <- impact_data[i, ]$Wereda
    #certainty <- impact_data[i, ]$Certainty
    Crop.Damages <- impact_data[i, ]$Crop.Damages
    Lost.Cattle <- impact_data[i, ]$Lost.Cattle   
    Affectd <- impact_data[i, ]$Affectd
    
    # Create description for top of plot
    description <- paste0(
      "Date: ", flood_date, " \t",
      "District: ", district, "\n",
      "Crop Damages: ", Crop.Damages, " \t",
      "Lost.Cattle: ", Lost.Cattle, " \t",
      "People Affected: ", Affectd, "\t"
    )
    
    # Filter rainfall data 
    date_from <- flood_date - t_delta
    date_to <- flood_date + t_delta
    
    hazard_sub <- hazard %>%filter(Date > date_from,Date < date_to) #%>%mutate(flood = ifelse(date == flood_date, TRUE, NA))
    
    # Filter if less than 30 rows because event is more in the future than rainfall data
    if (nrow(hazard_sub) < t_delta+1) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no hazard data available"), 
           cex = 3, col = "black")
      next()
    }
    
    # Filter if no weather data available
    if (nrow(hazard_sub %>% filter(!is.na(dis))) == 0) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no hazard data available"), 
           cex = 3, col = "black")
      next()
    }
    
    # Make plot facetwrapped for each variable
    p1 <- hazard_sub %>% ggplot(aes(x = Date,y=dis)) + geom_line(aes(colour = Lead_time)) +
      geom_vline(xintercept = flood_date, linetype="dotted",  color = "red", size=1.5) +
      #geom_text(x=flood_date, y=.75*max(hazard_sub$dis), label=paste()"Scatter plot")
      #geom_point(aes(y = value * flood), color = "red") + facet_wrap(~Lead_time) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            plot.title = element_text(hjust = 0.5, size = 10)) +
      ggtitle(description) +theme(legend.position = c(0.06, 0.75))
    
    p<-ggarrange(p1,impact_zone + rremove("x.text"),widths = c(2, 0.6),
                 labels = c("", "Location"),
                 ncol = 2, nrow = 1)
    print(p)
    
    
    
    
    
  }
  
  dev.off() 
}

#-------------------------read boundary shape files and stations----------------
for (elm in  names(eval(parse(text=paste("settings$",Country,sep=""))))){
  url$query <- list(service = "WFS",version = "2.0.0",request = "GetFeature",
                    typename = eval(parse(text=paste("settings$",Country,"$",elm,sep=""))),
                    outputFormat = "application/json")
  request <- build_url(url)
  data_read <- st_read(request)
  assign(elm,data_read)
} 

for (elm in  names(settings$general_geo)){
  url$query <- list(service = "WFS",
                    version = "2.0.0",
                    request = "GetFeature",
                    typename = eval(parse(text=paste("settings$general_geo","$",elm,sep=""))),
                    outputFormat = "application/json")
  request <- build_url(url)
  data_read <- st_read(request)
  assign(elm,data_read)
} # download Geo Data 

# download geo data
# check validity of shape files downloaded from geonode server 

admin3 <- admin3 %>%filter(st_is_valid(geometry))
impact_data <- impact_data %>%filter(st_is_valid(geometry))
admin2 <- admin2 %>%filter(st_is_valid(geometry))
admin3 <- st_transform(admin3, st_crs(crs1))
impact_data1_1 <- impact_data %>%
  mutate(date = as.Date(Date, format="%d/%m/%Y"),flood = 1) #%>% dplyr::select(-Region)



# Read rainfall data 
drr <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr.xls",
                  range = "A1:AO10001")%>% rename(Element="Elment",Gh_id = `Gh id`) %>% select(-`Eg gh id`)
drr2 <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr2.xls",
                   range = "A1:AL7551")%>% mutate(Gh_id='NA',Time='09:00')

# clean data 

rainfaa_df<- rbind(drr, drr2)%>% gather("date","Rainfall",-c("Gh_id","Name","Elevation",
                                        "Geogr1","Geogr2","Element","Year","Month" ,"Time" ))%>%
  mutate(date=substr(date,4,6))%>% filter(Rainfall!= 'NA')

# identify coordinate of rainfall stations

rainfaa_stations<- rainfaa_df %>% distinct(Name,.keep_all = TRUE)
 
rainfaa_stations_sf <- st_as_sf(rainfaa_stations, coords = c("Geogr1","Geogr2")) %>%  st_set_crs(4326)

ggplot() +   geom_sf(data = rainfaa_stations_sf) + 
  geom_sf(colour = "blue", size = 3,data=rainfaa_stations_sf) 
