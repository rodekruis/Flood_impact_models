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
prep_glofas_data <- function(){
  # Read glofas files
  glofas_files <- list.files(paste0(getwd(),'/input/Glofas/station_csv'),pattern = '.csv')
  glofas_stations <- str_match(glofas_files, '^(?:[^_]*_){3}([^.]*)')[,2]
  
  glofas_data <- map2_dfr(glofas_files, glofas_stations, function(filename,glofas_station) {
    suppressMessages(
      read.csv(file.path(paste0(getwd(),'/input/Glofas/station_csv') , filename))  %>%
        mutate(time=as.Date(time),year=format(as.Date(time, format="%d/%m/%Y"),"%Y"),station2 = glofas_station,dis_3day=dis_3,dis_7day=dis_7) %>%
        select(time,year,station,dis,dis_3day,dis_7day))})
  
  
  glofas_data <- glofas_data %>%
    select(time,year,station,dis,dis_3day,dis_7day)%>%rename(date = time)
  return(glofas_data)
}

fill_glofas_data <- function(glofas_data){
  
  glofas_filled <- tibble(date = seq(min(glofas_data$date), max(glofas_data$date), by = "1 day"))
  glofas_filled <- merge(glofas_filled, tibble(station = unique(glofas_data$station)))
  
  glofas_filled <- glofas_filled %>%
    left_join(glofas_data, by = c("station", "date")) %>%
    arrange(station, date) %>%
    mutate(dis = na.locf(dis),dis_3day = na.locf(dis_3day),dis_7day = na.locf(dis_7day))
  glofas_filled<-glofas_filled %>% distinct(date,station,.keep_all = TRUE)
  return(glofas_filled)
}

make_plots <- function(impact_zone,impact_data,hazard,var="Rainfall",pdf_name){
  pdf(pdf_name, width=9, height=7)
  impact<- impact_data %>% mutate(Date_=as.Date(Date,format="%d/%m/%Y"))
  flood_date <- impact$Date_
  description <- paste0(
    "station: ", st, " \t",
    "Zone: ", zones, "\n"
  )
  if (var =="Rainfall"){
  p1 <-  hazard %>% ggplot(aes(x = Date,y=var))  + geom_line(aes(colour = cum_days))+
    geom_vline(xintercept = flood_date, linetype="dotted",  color = "red", size=1.5) +
    #geom_text(x=flood_date, y=.75*max(hazard_sub$Rainfall), label=paste()"Scatter plot")
    #geom_point(aes(y = value * flood), color = "red") + facet_wrap(~Lead_time) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1),
          plot.title = element_text(hjust = 0.5, size = 10))+  ggtitle(description) +
    theme(legend.position = c(0.06, 0.75))}
  if (var == "dis"){
    p1 <- hazard_sub %>% ggplot(aes(x = Date,y=dis)) + geom_line(aes(colour = Lead_time)) +
      geom_vline(xintercept = flood_date, linetype="dotted",  color = "red", size=1.5) +
      #geom_text(x=flood_date, y=.75*max(hazard_sub$dis), label=paste()"Scatter plot")
      #geom_point(aes(y = value * flood), color = "red") + facet_wrap(~Lead_time) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            plot.title = element_text(hjust = 0.5, size = 10)) +
      ggtitle(description) +theme(legend.position = c(0.06, 0.75))
  }
  
  
  
  p<-ggarrange(p1,impact_zone + rremove("x.text"),widths = c(2, 0.6),
               labels = c("", "Location"),
               ncol = 2, nrow = 1)
  print(p)
  dev.off() 
}

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

#---------------------- aggregate IMpact data for admin 2 admin 1 -------------------------------
# to do define impact columns in setting file in Ethiopian Case Crop.Damages, Lost.Cattle,Affected 
impact_data1_w_ts <- impact_data1_1 %>% mutate(Affected=as.numeric(Affectd),
                                              Lost.Cattle=as.numeric(Lst_Ctt),
                                              Crop.Damages=as.numeric(Crp_Dmg),
                                              flood=1) %>% 
  select(Region,Zone,Wereda,Pcode,Date,Affected,Lost.Cattle,Crop.Damages,flood)

impact_data1_Z<-impact_data1_w_ts %>% group_by(Zone) %>%  summarise(Affected = sum(Affected,na.rm=TRUE),
                                                                    geometry=st_union(geometry),
                                                                    Crop.Damages = sum(Crop.Damages,na.rm=TRUE),
                                                                    Lost.Cattle = sum(Lost.Cattle,na.rm=TRUE)) %>%ungroup()

impact_data1_Z%>%st_set_geometry(impact_data1_Z$geometry)
impact_data1_Z <- impact_data1_Z %>%filter(st_is_valid(geometry))
impact_data1_Z <- st_transform(impact_data1_Z, st_crs(basins_africa))



impact_data1_w<-impact_data1_w_ts %>% group_by(Wereda) %>%  summarise(Affected = sum(Affected,na.rm=TRUE),
                                                                      Crop.Damages = sum(Crop.Damages,na.rm=TRUE),
                                                                      Lost.Cattle = sum(Lost.Cattle,na.rm=TRUE)) %>%ungroup()

impact_data1_R<-impact_data1_w_ts %>% group_by(Region) %>%  summarise(Affected = sum(Affected,na.rm=TRUE),
                                                                      geometry=st_union(geometry),
                                                                      Crop.Damages = sum(Crop.Damages,na.rm=TRUE),
                                                                      Lost.Cattle = sum(Lost.Cattle,na.rm=TRUE)) %>%ungroup()#%>%  st_set_geometry(NULL)

impact_data1_R%>%st_set_geometry(impact_data1_R$geometry)


#---------------------- Hydro/mettrological stations in affected regions -------------------------------
river_eth <- st_intersection(rivers, admin1) %>% filter(UP_CELLS>1500) ##arrange(desc(UP_CELLS)) %>% dplyr::select(ARCID,geometry)
eth_glofas_st<-glofas_st %>% filter(CountryNam =='Ethiopia')%>% mutate(station=id) %>% select(station) 

# based on nearest glogas station with in 50km from the impacted wareda 
admin_centroid_pts <- impact_data1_w_ts %>%mutate(cent_lon=map_dbl(geometry, ~st_centroid(.x)[[1]]), 
                                                  cent_lat=map_dbl(geometry, ~st_centroid(.x)[[2]])) %>% as.data.frame() %>% distinct(Wereda,Zone,.keep_all = TRUE)

# convert to simple dataframe
admin_centroid_pts <- st_as_sf(admin_centroid_pts, coords = c("cent_lon","cent_lat"), crs=4326, remove = FALSE) %>%  select(Wereda,Zone)
admin_centroid_pts = st_transform(admin_centroid_pts, 4326)
eth_glofas_st = st_transform(eth_glofas_st, 4326)


# find the first nearest neighbor rainfall station station for each centroid,  maximum 
glofas_stations_in_affected_areas<-st_join(admin_centroid_pts, eth_glofas_st, st_nn, k = 2,maxdist = 50000)%>% st_set_geometry(NULL)%>% select(Zone,station) %>% filter(station !='NA')
glofas_stations_in_affected_areas<-glofas_stations_in_affected_areas  %>% distinct(Zone,station,.keep_all = TRUE)

NAM_stations_in_affected_areas<-st_join(admin_centroid_pts, NMA_stations, st_nn, k = 2,maxdist = 20000)%>% st_set_geometry(NULL)%>% select(Zone,station) %>% filter(station !='NA')
NAM_stations_in_affected_areas<-NAM_stations_in_affected_areas  %>% distinct(Zone,station,.keep_all = TRUE)

hyd_stations_in_affected_areas<-st_join(admin_centroid_pts, eth_hydro_st, st_nn, k = 2,maxdist = 30000)%>% st_set_geometry(NULL)%>% select(Zone,station) %>% filter(station !='NA')
hyd_stations_in_affected_areas<-hyd_stations_in_affected_areas  %>% distinct(Zone,station,.keep_all = TRUE)

#---------------------- vistualize stations and risk areas -------------------------------
tmap_mode(mode = "view")
tm_shape(impact_data1_Z) + tm_polygons(col = "Affected", name='W_Name',
                                       palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                       breaks=c(0,5,1000,5000,20000,50000,90000),colorNA=NULL,
                                       labels=c('< 5','5 - 1k','1k - 5k','5k - 20k','20k - 50k','50k - 90k'),
                                       title="No of Affected People",
                                       border.col = "black",lwd = 0.5,lyt='dotted')+
  #tm_shape(NMA_stations_) + tm_symbols(size=0.5,border.alpha = 0.25,col='#045a8d') +
  tm_shape(eth_hydro_st_) + tm_symbols(size=0.5,border.alpha = 0.5,col='#74a9cf') +
  #tm_shape(Eth_affected_area_stations_ZONE) + tm_symbols(size=0.9,border.alpha = 0.25,col='#045a8d') +
  tm_shape(eth_hydro_st) + tm_text("SITE",size=.45)+ 
  tm_symbols(size=0.25,border.alpha = 0.5,col='#bdbdbd') +
  #tm_shape(NMA_stations) + tm_text("Gh_id",size=.5)+ 
  #tm_symbols(size=0.25,border.alpha = 0.25,col='#bdbdbd') +
  #tm_shape(river_eth) + tm_lines(lwd=1,alpha = 0.5,col='#74a9cf') +
  #tm_shape(eth_admin3) + tm_borders(lwd = .5,col='#bdbdbd') + #
  tm_format("NLD")
#---------------------- read glofas data hazard ------------------------------- 
glofas_data<-prep_glofas_data()
fill_glofas_data_<-fill_glofas_data(glofas_data)

make_glofas_district_matrix <- function(glofas_data,glofas_stations_in_affected_areas) {
  
  #glofas_with_regions <- read_csv(paste0(getwd(),'/input/Eth_affected_area_stations.csv')) %>% mutate(station=st1)
  #glofas_with_regions<- eth_glofas_st_zone %>% gather('st_id','station',-Z_NAME)  %>% filter(station != 'NA')
  #glofas_with_regions<- Eth_affected_area_stations_ZONE %>% select(Z_NAME,station)
  
  glofas_data <- glofas_data %>% 
    left_join(glofas_stations_in_affected_areas, by="station") %>% filter(Zone !='Na')  %>% # spread(station, dis_3day) %>%  mutate(district = toupper(Z_NAME)) %>%
    arrange(Zone, date)%>% rename(Date=date)  
  return(glofas_data)
}

glofas_district_matrix<- make_glofas_district_matrix(fill_glofas_data_,glofas_stations_in_affected_areas)

#---------------------- Rainfall data NAM -------------------------------
# Read rainfall data 
drr <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr.xls",
                  range = "A1:AO10001")%>% rename(Element="Elment",Gh_id = `Gh id`) %>% select(-`Eg gh id`)
drr2 <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr2.xls",
                   range = "A1:AL7551")%>% mutate(Gh_id='NA',Time='09:00')
drr3 <- read_excel("C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/input/rainfall/drr3.xlsx",
                   range = "A1:AM7551")%>% mutate(Time='09:00')%>% rename(Element=Elements)
# clean data 
rainfall_df<- rbind(drr, drr2,drr3)%>% gather("date","Rainfall",-c("Gh_id","Name","Elevation",
                                                              "Geogr1","Geogr2","Element","Year","Month" ,"Time" ))%>%
  mutate(date=substr(date,4,6),time=as.Date(paste0(Year,'-',Month,'-',date), format="%Y-%m-%d"))%>% filter(Rainfall!= 'NA')





# identify coordinate of rainfall stations
rainfall_stations<- rainfall_df %>% distinct(Name,.keep_all = TRUE)
rainfall_stations_sf <- st_as_sf(rainfall_stations, coords = c("Geogr1","Geogr2")) %>% 
  st_set_crs(4326)%>% select(Name,Gh_id,Elevation)

#---------------------- Hydro/mettrological stations in affected regions -------------------------------

# find the first nearest neighbor rainfall station station for each centroid, 
NAM_stations_in_affected_weredas<-st_join(admin_centroid_pts, rainfall_stations_sf, st_nn, k = 2,maxdist = 20000)%>% st_set_geometry(NULL)%>% select(Zone,Name,Gh_id)  %>% filter(Name !='NA')
NAM_stations_in_affected_zones<-NAM_stations_in_affected_weredas  %>%
  distinct(Zone,Name,.keep_all = TRUE)

make_rainfall_district_matrix <- function(rainfall_df,NAM_stations_in_affected_zones) {
  
  rainfall_data <- rainfall_df %>% 
    left_join(NAM_stations_in_affected_zones, by="Name") %>% filter(Zone !='Na')  %>% # spread(station, dis_3day) %>%  mutate(district = toupper(Z_NAME)) %>%
    arrange(Zone, time)%>% rename(Date=time)  %>% select(Name,Zone,Date,Rainfall)
  return(rainfall_data)
}

rainfall_district_matrix<- make_rainfall_district_matrix(rainfall_df,NAM_stations_in_affected_zones) %>% rename(rain_station=Name)

data_matrix<-rainfall_district_matrix %>% full_join(glofas_district_matrix %>% select(-year),by=c("Date","Zone"))
impact_data_df<- impact_data1_w_ts %>% st_set_geometry(NULL)

Impact_hazard_catalog<- data_matrix  %>% full_join(impact_data_df %>% mutate(Date=as.Date(Date,format="%d/%m/%Y")),by=c("Date","Zone"))

###### write Impact hazard catalog to file 
write.table(Impact_hazard_catalog, file = "C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/dashboard/catalog_view_Ethiopia/data/Impact_Hazard_catalog.csv", append = FALSE, quote = TRUE, sep = ";",
            eol = "\n", na = "NA", dec = ".", row.names = FALSE,
            col.names = TRUE, qmethod = c("escape", "double"),
            fileEncoding = "")

### make plots for EAP
 for (zones in unique(impact_data_df$Zone))
  {
  Hazard_glofas <- glofas_district_matrix %>% filter(Zone ==!!zones)# %>%   pull()
  impact<-impact_data_df %>% filter(Zone ==!!zones) 
  for (st  in unique(Hazard_glofas$station)){
    print(st)
    plot_data <- Hazard_glofas %>%filter(station == !!st) %>% select(-year) %>%
      rename(t0=dis,t_3days=dis_3day, t_7days=dis_7day) %>% 
      gather('Lead_time','dis',-Date,-station,-Zone)
    #p<- ggplot(plot_data, aes(Date,dis)) + geom_line(aes(colour = Lead_time))
    
    impact_zone <- ggplot() +   geom_sf(data = admin2) + 
      geom_sf(data = admin2 %>% filter(Z_NAME ==!!zones),col ='red',fill = 'red') +
      geom_sf(colour = "blue", size = 3,data=glofas_st %>% filter(glofas_st$id %in% st)) +theme(  axis.text.x = element_blank(),
                                                                                                  axis.text.y = element_blank(),
                                                                                                  axis.ticks = element_blank())
    
    
    #p<- ggplot(plot_data, aes(Date,dis)) + geom_line(aes(colour = Lead_time))
    make_zoomed_in_plots(impact_zone=impact_zone,impact=impact,hazard=plot_data,t_delta=100,pdf_name=paste0(getwd(),"/output/Ethiopia/",zones,st,"zoomed_in_per_flood.pdf"))
    
    #print(p)
    ### make plots per zone 
    make_plots(impact_zone=impact_zone,impact=impact,hazard=plot_data,var="Rainfall",pdf_name=paste0(getwd(),"/output/Ethiopia/Rainfall/",zones,st,"_flood_rain.pdf"))
    
    
   # p <- plot_data %>%  ggplot(aes(x = date, y = dis)) + geom_line() + geom_label(aes(y=dis, label=label)) +
    #ggtitle(station) + theme(plot.title = element_text(hjust = 0.5, size = 16))
   
  }
}




 




