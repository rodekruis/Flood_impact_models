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
Country="kenya"
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
} # download geo 

# read glofas station
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


# read river and catchment boundaries 
for (elm in  names(settings$general_basin)){
  url$query <- list(service = "WFS",
                    version = "2.0.0",
                    request = "GetFeature",
                    typename = eval(parse(text=paste("settings$general_basin","$",elm,sep=""))),
                    outputFormat = "application/json")
  request <- build_url(url)
  data_read <- st_read(request)
  assign(elm,data_read)
} # download Geo Data 


admin1 <- admin1 %>%filter(st_is_valid(geometry))
impact_data <- impact_data %>%filter(st_is_valid(geometry))
admin2 <- admin2 %>%filter(st_is_valid(geometry))

#admin3 <- st_transform(admin3, st_crs(crs1))

river_kenya <- st_intersection(rivers, admin1) %>% filter(UP_CELLS>1500) ##arrange(desc(UP_CELLS)) %>% dplyr::select(ARCID,geometry)
#river_eth <-river_eth %>% filter(UP_CELLS>7500)

kenya_glofas_st<-glofas_st %>% filter(CountryNam=='Kenya')
#---------------------- aggregate IMpact data for admin 2 admin 1 -------------------------------
# to do define impact columns in setting file in Ethiopian Case Crop.Damages, Lost.Cattle,Affected 

impact_data_ts <- impact_data %>% mutate(Affected=as.numeric(p_impact),
                                              HH_impact=as.numeric(hh_impact),
                                         human_impact=as.numeric(human_impa))%>% st_set_geometry(NULL)



impact_data_County_ts<- admin1 %>%  mutate(County=ADM1_EN)  %>% select(County) %>%
  left_join(impact_data_ts ,by="County")

impact_data_County<-impact_data_ts %>% group_by(County) %>%
  summarise(Affected = sum(Affected,na.rm=TRUE),HH_impact = sum(HH_impact,na.rm=TRUE),human_impact = sum(human_impact,na.rm=TRUE)) %>%
  ungroup()

impact_data_County<-impact_data_County %>% 
  left_join(admin1 %>% mutate(County=ADM1_EN),by="County")
 
 
impact_data_County<-impact_data_County%>%st_set_geometry(impact_data_County$geometry)

impact_data_County <- impact_data_County %>%filter(st_is_valid(geometry))
impact_data_County <- st_transform(impact_data_County, st_crs(basins_africa))

#write.csv(impact_data1,"C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/data/Eth_impact_data.csv", row.names = FALSE)

#---------------------- annimation risk map -------------------------------
tmap_mode(mode = "plot")

m1<-tm_shape(admin1) + tm_borders(lwd = .5,col='#bdbdbd') +
  tm_shape(impact_data_County_ts) + tm_polygons(col = "Affected", name='County',
                                        palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                        breaks=c(0,5,10,50,200,500,900),colorNA=NULL,
                                        labels=c('< 5','5 - 10','10 - 50','50 - 200','200 - 500','500 - 900'),
                                        title="No of Affected People",
                                        border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_facets(along = "Date_year",free.coords = FALSE) +
  tm_format("World_wide")
#save annimation to file 
tmap_animation(m1, filename="kenya_impact.gif", width=1600, delay=60)

#---------------------- visualize risk data This are potential maps for EAP -------------------------------


impact_data1_Z_<-impact_data_County  %>%   top_n(20,wt=Affected)
#par(mar=c(11.5, 4.5, 13.15, 2.25)+0.2)
par(mfrow = c(1,3),mar=c(6.5, 4.5, 5.15, 2.25)+0.2)
barplot(impact_data1_Z_$Affected, names = impact_data1_Z_$County,
        las = 3, cex.axis = 1, cex.names = 1, ylab = "Total No of people affected", cex.lab = 1.7, space = 0,
        col = "#fc9272",        main = "Most affected County \n by #of affected people",
        cex.main =1.7)


barplot(impact_data1_Z_$HH_impact, names =impact_data1_Z_$County,
        las = 3, cex.axis = 1.0, cex.names = 1, ylab = "Total HH affected", cex.lab = 1.7, space = 0,
        col = "#fc9272",        main = "Most affected County \n by HH affected",
        cex.main =1.7)

barplot(impact_data1_Z_$human_impact, names = impact_data1_Z_$County,
        las = 3, cex.axis = 1.0, cex.names = 1.0, ylab = "Total human impact", cex.lab = 1.7, space = 0,
        col = "#fc9272",        main = "Most affected County\n by human impact",
        cex.main = 1.7)
#---------------------- spatial plot of the most affected County and zones ------------------------------- 

tmap_mode(mode = "view")
tm_shape(impact_data_County) + tm_polygons(col = "Affected", name='County',
                                   palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                   breaks=c(0,5,1000,5000,20000,50000,90000),colorNA=NULL,
                                   labels=c('< 5','5 - 1k','1k - 5k','5k - 20k','20k - 50k','50k - 90k'),
                                   title="No of Affected People",
                                   border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(river_kenya) + tm_lines(lwd=1,alpha = 0.5,col='#74a9cf') +
  tm_shape(admin1) + tm_borders(lwd = .5,col='#bdbdbd') + #+   tm_format("NLD")
  
tm_layout(frame=F,scale = 1.5, legend.position = c(.78,.82), 
          legend.outside.size = 0.1,
          legend.title.size = 2.0,
          legend.height = 0.9,
          legend.text.size = 1.6, 
          legend.hist.size = 0.6) +tm_format("World_wide")

#tmap_save(map1,width=1959, height=1791,dpi=400,
         # filename = ('C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/output/Affected_number_of_people.png'))


# tmap


#map<- tmap_arrange(map1,map2,map3,ncol = 3,widths = c(.33,.33,.33))

#---------------------- Hydro/mettrological stations in affected regions -------------------------------


glofas_stations_in_affected_areas<-st_intersection(kenya_glofas_st,impact_data1_Z_) %>% filter(id !='Na')  %>% select(id) %>%  
  st_set_geometry(NULL)
glofas_stations_in_affected_areas<- kenya_glofas_st %>% filter(id %in% glofas_stations_in_affected_areas$id)


#---------------------- vistualize stations and risk areas -------------------------------

tmap_mode(mode = "view")
tm_shape(impact_data_County) + tm_polygons(col = "HH_impact", name='County',
                                       palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                       breaks=c(0,5,100,500,2000,5000,10000),colorNA=NULL,
                                       labels=c('< 5','5 - 100','100 - 500','500 - 2k','2k - 5k','5k - 10k'),
                                       title="No of Affected People",
                                       border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(glofas_st) + tm_symbols(size=0.5,border.alpha = 0.25,col='#045a8d') +
  tm_shape(kenya_glofas_st) + tm_symbols(size=0.5,border.alpha = 0.5,col='#74a9cf') +
  #tm_shape(Eth_affected_area_stations_ZONE) + tm_symbols(size=0.9,border.alpha = 0.25,col='#045a8d') +
  #tm_shape(NMA_stations) + tm_text("Gh_id",size=.5)+ 
  #tm_symbols(size=0.25,border.alpha = 0.25,col='#bdbdbd') +
  tm_shape(river_kenya) + tm_lines(lwd=1,alpha = 0.5,col='#74a9cf') +
  tm_shape(admin2) + tm_borders(lwd = .5,col='#bdbdbd') + #
  tm_format("NLD")

#write.csv(eth_hydro_st_,  "C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/data/Eth_hydro_selected_stations.csv", row.names = FALSE)
#write.csv(eth_glofas_st,"C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/input/Eth_affected_area_stations.csv", row.names = FALSE)

