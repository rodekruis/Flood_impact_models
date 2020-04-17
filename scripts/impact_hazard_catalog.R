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
#---------------------- setting -------------------------------
Country="Ethiopia"
setwd(dirname(rstudioapi::getSourceEditorContext()$path))
source("Geo_settings.R")
settings <- country_settings
url<- parse_url(url_geonode)
# raead boundary shape files and stations 
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
river_eth <- st_intersection(rivers, admin1) %>% filter(UP_CELLS>1500) ##arrange(desc(UP_CELLS)) %>% dplyr::select(ARCID,geometry)
eth_glofas_st<-st_intersection(glofas_st,impact_data) %>% filter(id !='Na')  %>% mutate(station=id) %>% select(station,Zone,Wereda) #%>%   st_set_geometry(NULL)


impact_data1_1 <- impact_data %>%
  mutate(date = as.Date(Date, format="%d/%m/%Y"),flood = 1) #%>% dplyr::select(-Region)

#---------------------- aggregate IMpact data for admin 2 admin 1 -------------------------------
# to do define impact columns in setting file in Ethiopian Case Crop.Damages, Lost.Cattle,Affected 
impact_data1_w_ts <- impact_data1_1 %>% mutate(Affected=as.numeric(Affectd),
                                              Lost.Cattle=as.numeric(Lst_Ctt),
                                              Crop.Damages=as.numeric(Crp_Dmg)) 

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

NAM_stations_in_affected_areas<-st_intersection(NMA_stations,impact_data1_Z) %>% filter(Gh_id !='Na')  %>% #select(Gh_id) %>%  
  st_set_geometry(NULL)

NMA_stations_<- NMA_stations %>% filter(Gh_id %in% NAM_stations_in_affected_areas$Gh_id)

hyd_stations_in_affected_areas<-st_intersection(eth_hydro_st,impact_data1_Z) %>% filter(SITE !='Na')  %>% #select(Gh_id) %>%  
  st_set_geometry(NULL)
eth_hydro_st_<- eth_hydro_st %>% filter(SITE %in% hyd_stations_in_affected_areas$SITE)

eth_glofas_st<-st_intersection(glofas_st,admin1) %>% filter(id !='Na')  %>% select(id) %>%  
  st_set_geometry(NULL)
eth_glofas_st<- glofas_st %>% filter(id %in% eth_glofas_st$id)


glofas_stations_in_affected_areas<-st_intersection(eth_glofas_st,impact_data1_Z) %>% filter(id !='Na')  %>% select(id) %>%  
  st_set_geometry(NULL)
glofas_stations_in_affected_areas<- eth_glofas_st %>% filter(id %in% glofas_stations_in_affected_areas$id)

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


prep_glofas_data <- function(){
  # Read glofas files
  
  
  # Read glofas files
  glofas_files <- list.files(paste0(getwd(),'/input/Glofas/station_csv'),pattern = '.csv')
  glofas_stations <- str_match(glofas_files, '^(?:[^_]*_){3}([^.]*)')[,2]
  
  #glofas_files1 <- str_match(glofas_files, '^(?:[^_]*_){2}([^.]*)')[,1]
  #glofas_stations <-c('G1904','G1905','G1906')
  
  glofas_data <- map2_dfr(glofas_files, glofas_stations, function(filename,glofas_station) {
    suppressMessages(
      read_csv(file.path(paste0(getwd(),'/input/Glofas/station_csv') , filename))  %>%
        mutate(time=as.Date(time),year=format(as.Date(time, format="%d/%m/%Y"),"%Y"),station2 = glofas_station,dis_3day=dis_3,dis_7day=dis_7) %>%
        select(time,year,station,dis,dis_3day,dis_7day))})
  
  
  glofas_data <- glofas_data %>%
    select(time,year,station,dis,dis_3day,dis_7day)%>%
    rename(date = time)
  
  
  
  return(glofas_data)
}

glofas_data<-prep_glofas_data()

fill_glofas_data <- function(glofas_data){
  
  glofas_filled <- tibble(date = seq(min(glofas_data$date), max(glofas_data$date), by = "1 day"))
  glofas_filled <- merge(glofas_filled, tibble(station = unique(glofas_data$station)))
  
  glofas_filled <- glofas_filled %>%
    left_join(glofas_data, by = c("station", "date")) %>%
    arrange(station, date) %>%
    mutate(dis = na.locf(dis),dis_3day = na.locf(dis_3day),dis_7day = na.locf(dis_7day))
  
  return(glofas_filled)
}

fill_glofas_data_<-fill_glofas_data(glofas_data)

glofas_with_regions<- eth_glofas_st_zone %>% gather('st_id','station',-Z_NAME)  %>% filter(station != 'NA')

#glofas_with_regions1<- Eth_affected_area_stations_ZONE %>% select(Z_NAME,station)

make_glofas_district_matrix <- function(glofas_data,glofas_with_regions) {
  
  #glofas_with_regions <- read_csv(paste0(getwd(),'/input/Eth_affected_area_stations.csv')) %>% mutate(station=st1)
  #glofas_with_regions<- eth_glofas_st_zone %>% gather('st_id','station',-Z_NAME)  %>% filter(station != 'NA')
  #glofas_with_regions<- Eth_affected_area_stations_ZONE %>% select(Z_NAME,station)
  
  glofas_data <- glofas_data %>%
    left_join(glofas_with_regions, by="station") %>%
    spread(station, dis_3day) %>%
    mutate(district = toupper(Z_NAME)) %>%
    arrange(district, date)
  
  
  return(glofas_data)
}







# ------------------- Plots per station -----------------------------
pdf("output/flood_per_station2.pdf", width=11, height=8.5)

for (station in unique(glofas_with_regions$Z_NAME)){
  districts <- glofas_with_regions %>% filter(Z_NAME == !!station) %>% dplyr::select(station) #%>%     pull()
  
  floods <- impact_data1_1 %>%
    filter(district %in% station) %>%
    dplyr::select(district, date, impact = Affected)
  
  
  print(floods)
  for (st  in unique(districts$station)){
    print(st)
    plot_data <- fill_glofas_data_ %>%
      filter(station == !!st) %>% left_join(floods, by = "date") %>%
      mutate(label = ifelse(!is.na(district), district, NA),dis = replace_na(dis_3day, 0))
    
    p <- plot_data %>%
      ggplot(aes(x = date, y = dis)) + geom_line() + geom_label(aes(y=dis, label=label)) +
      ggtitle(station) + theme(plot.title = element_text(hjust = 0.5, size = 16))
    print(p)
  }
}

for (station in unique(glofas_with_regions$station)) {
  districts <- glofas_with_regions %>% 
    filter(station == !!station) %>%
    dplyr::select(Z_NAME) %>%
    pull()
  
  floods <- impact_data1_1 %>%
    filter(district %in% districts) %>%
    dplyr::select(district, date, impact = Affected)
  
  plot_data <- fill_glofas_data_ %>%
    filter(station == !!station) %>%
    left_join(floods, by = "date") %>%
    mutate(label = ifelse(!is.na(district), district, NA),
           dis = replace_na(dis_3day, 0))
  
  p <- plot_data %>%
    ggplot(aes(x = date, y = dis)) + geom_line() + geom_label(aes(y=dis, label=label)) +
    ggtitle(station) + theme(plot.title = element_text(hjust = 0.5, size = 16))
  print(p)
}

dev.off()


 




