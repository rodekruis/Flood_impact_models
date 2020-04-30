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
library(purrr)
library(nngeo)
library(readxl)
#---------------------- setting -------------------------------
Country="Ethiopia"
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

source("Geo_settings.R")
setwd('../')
settings <- country_settings
url<- parse_url(url_geonode)

#----------------------------function defination -------------

make_zoomed_in_plots <- function(impact_zone,impact_data,hazard,t_delta=30,pdf_name){
  pdf(pdf_name, width=9, height=7)
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
    if (nrow(hazard_sub %>% filter(!is.na(Rainfall))) == 0) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no hazard data available"), 
           cex = 3, col = "black")
      next()
    }
       
    # Make plot facetwrapped for each variable
   p1 <-  hazard_sub %>% ggplot(aes(x = Date,y=Rainfall))  + geom_line(aes(colour = cum_days))+
      geom_vline(xintercept = flood_date, linetype="dotted",  color = "red", size=1.5) +
      #geom_text(x=flood_date, y=.75*max(hazard_sub$Rainfall), label=paste()"Scatter plot")
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


# download geo data
# check validity of shape files downloaded from geonode server 

admin3 <- admin3 %>%filter(st_is_valid(geometry))
impact_data <- impact_data %>%filter(st_is_valid(geometry))
admin2 <- admin2 %>%filter(st_is_valid(geometry))
admin3 <- st_transform(admin3, st_crs(crs1))
impact_data1_1 <- impact_data %>% mutate(date = as.Date(Date, format="%d/%m/%Y"),flood = 1) #%>% dplyr::select(-Region)

#---------------------- aggregate IMpact data for admin 2 admin 1 -------------------------------
# to do define impact columns in setting file in Ethiopian Case Crop.Damages, Lost.Cattle,Affected 
impact_data1_w_ts <- impact_data1_1 %>% mutate(Affected=as.numeric(Affectd),
                                               Lost.Cattle=as.numeric(Lst_Ctt),
                                               Crop.Damages=as.numeric(Crp_Dmg)) %>% 
  select(Region,Zone,Wereda,Pcode,Date,Affected,Lost.Cattle,Crop.Damages)

impact_data1_w<-impact_data1_w_ts %>% group_by(Wereda) %>%  summarise(Affected = sum(Affected,na.rm=TRUE),
                                                                      Crop.Damages = sum(Crop.Damages,na.rm=TRUE),
                                                                      Lost.Cattle = sum(Lost.Cattle,na.rm=TRUE)) %>%ungroup()




# Read rainfall data 
drr <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr.xls",
                  range = "A1:AO10001")%>% rename(Element="Elment",Gh_id = `Gh id`) %>% select(-`Eg gh id`)
drr2 <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr2.xls",
                   range = "A1:AL7551")%>% mutate(Gh_id='NA',Time='09:00')
drr3 <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr3.xlsx",
                   range = "A1:AL7551")%>% mutate(Gh_id='NA',Time='09:00')

# clean data 
rainfall_df<- rbind(drr, drr2)%>% gather("date","Rainfall",-c("Gh_id","Name","Elevation",
                                        "Geogr1","Geogr2","Element","Year","Month" ,"Time" ))%>%
  mutate(date=substr(date,4,6),time=as.Date(paste0(Year,'-',Month,'-',date), format="%Y-%m-%d"))%>% filter(Rainfall!= 'NA')

# identify coordinate of rainfall stations
rainfall_stations<- rainfall_df %>% distinct(Name,.keep_all = TRUE)
rainfall_stations_sf <- st_as_sf(rainfall_stations, coords = c("Geogr1","Geogr2")) %>% 
  st_set_crs(4326)%>% select(Name,Gh_id,Elevation)

#---------------------- Hydro/mettrological stations in affected regions -------------------------------

admin_centroid_pts <- impact_data1_w_ts %>%mutate(cent_lon=map_dbl(geometry, ~st_centroid(.x)[[1]]), 
         cent_lat=map_dbl(geometry, ~st_centroid(.x)[[2]])) %>% as.data.frame() %>% distinct(Wereda,Zone,.keep_all = TRUE)
   # convert to simple dataframe

admin_centroid_pts <- st_as_sf(admin_centroid_pts, coords = c("cent_lon","cent_lat"), crs=4326, remove = FALSE) %>%
  select(Wereda,Zone)


# find the first nearest neighbor rainfall station station for each centroid, 
NAM_stations_in_affected_weredas<-st_join(admin_centroid_pts, rainfall_stations_sf, st_nn, k = 1)%>% st_set_geometry(NULL)%>% select(Zone,Name,Gh_id)

NAM_stations_in_affected_zones<-NAM_stations_in_affected_weredas  %>%
  distinct(Zone,Name,.keep_all = TRUE)

#---------------------- rainfall data as hazard ------------------------------- 

make_rainfall_district_matrix <- function(rainfall_df,NAM_stations_in_affected_zones) {
  
  rainfall_data <- rainfall_df %>% 
    left_join(NAM_stations_in_affected_zones, by="Name") %>% filter(Zone !='Na')  %>% # spread(station, dis_3day) %>%  mutate(district = toupper(Z_NAME)) %>%
    arrange(Zone, time)%>% rename(Date=time)  %>% select(Name,Zone,Date,Rainfall)
  return(rainfall_data)
}


rainfall_district_matrix<- make_rainfall_district_matrix(rainfall_df,NAM_stations_in_affected_zones)









impact_data_df<- impact_data1_w_ts %>% st_set_geometry(NULL)


############
make_plots <- function(impact_zone,impact_data,hazard,pdf_name){
  pdf(pdf_name, width=9, height=7)
  impact<- impact_data %>% mutate(Date_=as.Date(Date,format="%d/%m/%Y"))
  flood_date <- impact$Date_
  description <- paste0(
    "station: ", st, " \t",
    "Zone: ", zones, "\n"
  )
  p1 <-  hazard %>% ggplot(aes(x = Date,y=Rainfall))  + geom_line(aes(colour = cum_days))+
    geom_vline(xintercept = flood_date, linetype="dotted",  color = "red", size=1.5) +
    #geom_text(x=flood_date, y=.75*max(hazard_sub$Rainfall), label=paste()"Scatter plot")
    #geom_point(aes(y = value * flood), color = "red") + facet_wrap(~Lead_time) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1),
          plot.title = element_text(hjust = 0.5, size = 10))+  ggtitle(description) +
    theme(legend.position = c(0.06, 0.75))
  p<-ggarrange(p1,impact_zone + rremove("x.text"),widths = c(2, 0.6),
               labels = c("", "Location"),
               ncol = 2, nrow = 1)
  print(p)
  dev.off() 
}


for (zones in unique(impact_data_df$Zone))
{
  Hazard_rainfall <- rainfall_district_matrix %>% filter(Zone ==!!zones)# %>%   pull()
  impact<-impact_data_df %>% filter(Zone ==!!zones) 
  for (st  in unique(Hazard_rainfall$Name)){
    print(st)
    plot_data <- Hazard_rainfall %>%filter(Name == !!st)# %>% select(-year) %>%  rename(t0=dis,t_3days=dis_3day, t_7days=dis_7day) #%>%       gather('Lead_time','dis',-Date,-Name,-Zone)
    
    plot_data <- plot_data %>% mutate(rain_t2= rollapplyr(Rainfall, width = 2, FUN = sum, partial = TRUE),
                                      rain_t3 = rollapplyr(Rainfall, width = 3, FUN = sum, partial = TRUE),
                                      rain_t5 = rollapplyr(Rainfall, width = 5, FUN = sum, partial = TRUE))%>% 
      rename(rain_t0=Rainfall)%>% gather("cum_days","Rainfall",-Name,-Zone,-Date )
    
    impact_zone <- ggplot() +   geom_sf(data = admin2) + 
      geom_sf(data = admin2 %>% filter(Z_NAME ==!!zones),col ='red',fill = 'red') +
      geom_sf(colour = "blue", size = 3,data=rainfall_stations_sf %>% filter(rainfall_stations_sf$Name %in% st)) +theme(  axis.text.x = element_blank(),
                                                                                                  axis.text.y = element_blank(),
                                                                                                  axis.ticks = element_blank())
    
    
 
    ### uncoment the following line to save zoomed maps per event 
    
    #make_zoomed_in_plots(impact_zone=impact_zone,impact=impact,hazard=plot_data,t_delta=100,pdf_name=paste0(getwd(),"/output/Ethiopia/Rainfall/",zones,st,"zoomed_in_per_flood_rain.pdf"))
    
    ### make plots per zone 
    make_plots(impact_zone=impact_zone,impact=impact,hazard=plot_data,pdf_name=paste0(getwd(),"/output/Ethiopia/Rainfall/",zones,st,"_flood_rain.pdf"))
    

       #print(p)
    # p <- plot_data %>%  ggplot(aes(x = date, y = dis)) + geom_line() + geom_label(aes(y=dis, label=label)) +
    #ggtitle(station) + theme(plot.title = element_text(hjust = 0.5, size = 16))
    

    
  }
}
 

