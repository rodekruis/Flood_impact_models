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
Country='Ethiopia'
#setwd(dirname(rstudioapi::getSourceEditorContext()$path))
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
} # download geo data
# read river and catchment boundaries 
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

admin3 <- admin3 %>%filter(st_is_valid(geometry))
impact_admin3 <- impact_admin3 %>%filter(st_is_valid(geometry))
admin_zone <- admin2 %>%filter(st_is_valid(geometry))

admin3 <- st_transform(admin3, st_crs(crs1))

river_eth <- st_intersection(rivers, admin1) %>% filter(UP_CELLS>1500) ##arrange(desc(UP_CELLS)) %>% dplyr::select(ARCID,geometry)
#river_eth <-river_eth %>% filter(UP_CELLS>7500)

eth_glofas_st<-st_intersection(glofas_st,impact_admin3) %>% filter(id !='Na')  %>% mutate(station=id) %>% select(station,Zone,Wereda) #%>%   st_set_geometry(NULL)

#---------------------- aggregate IMpact data for admin 2 admin 1 -------------------------------
# to do define impact columns in setting file in Ethiopian Case Crop.Damages, Lost.Cattle,Affected 
impact_data1_w_ts <- impact_admin3 %>% mutate(Affected=as.numeric(Affectd),
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

#write.csv(impact_data1,"C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/data/Eth_impact_data.csv", row.names = FALSE)

#---------------------- annimation risk map -------------------------------
tmap_mode(mode = "plot")

m1<-tm_shape(admin3) + tm_borders(lwd = .5,col='#bdbdbd') +
  tm_shape(impact_data1_w_ts) + tm_polygons(col = "Affected", name='W_NAME',
                                        palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                        breaks=c(0,5,1000,5000,20000,50000,90000),colorNA=NULL,
                                        labels=c('< 5','5 - 1k','1k - 5k','5k - 20k','20k - 50k','50k - 90k'),
                                        title="No of Affected People",
                                        border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_facets(along = "year",free.coords = FALSE) +
  tm_format("World_wide")
#save annimation to file 
#tmap_animation(m1, filename="Ethiopia_impact.gif", width=1600, delay=60)

#---------------------- visualize risk data This are potential maps for EAP -------------------------------
par(mfrow = c(1,3),mar=c(6.5, 4.5, 5.15, 2.25)+0.2)
barplot(impact_data1_R$Affected, names = impact_data1_R$Region,
        las = 3, cex.axis = 0.6, cex.names = 0.9, ylab = " Total Number of affected People", cex.lab = 0.9, space = 0,
        col = "#fc9272",main = "Most affected Regions\n by #of affected people",cex.main = .7)

barplot(impact_data1_R$Crop.Damages, names = impact_data1_R$Region,
        las = 2, cex.axis = 0.6, cex.names = 0.9, ylab = "Total Area of Crope Damage", cex.lab = 0.9, space = 0,
        col = "#fc9272",main = "Most affected Regions\n by Crope Damage", cex.main = .7)

barplot(impact_data1_R$Lost.Cattle, names = impact_data1_R$Region,
        las = 3, cex.axis = .6, cex.names = 0.9, ylab = "Total Number of Lost Cattles", cex.lab = 0.9, space = 0,
        col = "#fc9272",main = "Most affected Regions\n by Lost Cattles", cex.main = .7)
#plot the most affected woedas and zones ------------------------------- 

impact_data1_Z_<-impact_data1_Z  %>%   top_n(20,wt=Affected)
#par(mar=c(11.5, 4.5, 13.15, 2.25)+0.2)
par(mfrow = c(1,3),mar=c(6.5, 4.5, 5.15, 2.25)+0.2)
barplot(impact_data1_Z_$Affected, names = impact_data1_Z_$Zone,
        las = 3, cex.axis = 1, cex.names = 1, ylab = "Total No of people affected", cex.lab = 1.7, space = 0,
        col = "#fc9272",        main = "Most affected Zones \n by #of affected people",
        cex.main =1.7)


barplot(impact_data1_Z_$Crop.Damages, names =impact_data1_Z_$Zone,
        las = 3, cex.axis = 1.0, cex.names = 1, ylab = "Total Area of Crop damage", cex.lab = 1.7, space = 0,
        col = "#fc9272",        main = "Most affected Zone \n by Crop Damage",
        cex.main =1.7)

barplot(impact_data1_Z_$Lost.Cattle, names = impact_data1_Z_$Zone,
        las = 3, cex.axis = 1.0, cex.names = 1.0, ylab = "Total No of Lost Cattles", cex.lab = 1.7, space = 0,
        col = "#fc9272",        main = "Most affected Zone\n by Lost Cattles",
        cex.main = 1.7)
#---------------------- spatial plot of the most affected woedas and zones ------------------------------- 

tmap_mode(mode = "view")
tm_shape(impact_data1_w) + tm_polygons(col = "Affected", name='W_Name',
                                   palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                   breaks=c(0,5,1000,5000,20000,50000,90000),colorNA=NULL,
                                   labels=c('< 5','5 - 1k','1k - 5k','5k - 20k','20k - 50k','50k - 90k'),
                                   title="No of Affected People",
                                   border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(river_eth) + tm_lines(lwd=1,alpha = 0.5,col='#74a9cf') +
  tm_shape(admin3) + tm_borders(lwd = .5,col='#bdbdbd') + #+   tm_format("NLD")
  
tm_layout(frame=F,scale = 1.5, legend.position = c(.78,.82), 
          legend.outside.size = 0.1,
          legend.title.size = 2.0,
          legend.height = 0.9,
          legend.text.size = 1.6, 
          legend.hist.size = 0.6) +tm_format("World_wide")

#tmap_save(map1,width=1959, height=1791,dpi=400,
         # filename = ('C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/output/Affected_number_of_people.png'))


# tmap
tmap_mode(mode = "view")
tm_shape(impact_data1_w) + tm_polygons(col = "Crop.Damages",name='W_Name',
                                       palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                       breaks=c(0,5,50,200,1000,2000,4000),colorNA=NULL,
                                       labels=c('< 5','5 - 50','50 - 200','200 - 1k','2k - 4k',' >4k'),
                                       title="Area of Damaged Crops",
                                       border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(eth_admin3) + tm_borders(lwd = .5,col='#bdbdbd') +
  tm_layout(frame=F,scale = 1.5, legend.position = c(.78,.82), 
            legend.outside.size = 0.1,
            legend.title.size = 2.0,
            legend.height = 0.9,
            legend.text.size = 1.6, 
            legend.hist.size = 0.6) +tm_format("World_wide")
 

# tmap
tmap_mode(mode = "view")
tm_shape(impact_data1_w) + tm_polygons(col = "Lost.Cattle",name='W_Name',
                                       palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                       breaks=c(0,5,500,2000,10000,20000,40000),colorNA=NULL,
                                       labels=c('< 5','5 - 500','500 - 2k','2k - 10k','10k - 20k',' >40k'),
                                       title="Total Lost Cattle",
                                       border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(eth_admin3) + tm_borders(lwd = .5,col='#bdbdbd') +
  tm_layout(frame=F,scale = 1.5, legend.position = c(.78,.82), 
            legend.outside.size = 0.1,
            legend.title.size = 2.0,
            legend.height = 0.9,
            legend.text.size = 1.6, 
            legend.hist.size = 0.6) +tm_format("World_wide")


#map<- tmap_arrange(map1,map2,map3,ncol = 3,widths = c(.33,.33,.33))

#---------------------- Hydro/mettrological stations in affected regions -------------------------------

NAM_stations_in_affected_areas<-st_intersection(NMA_stations,impact_data1_Z) %>% filter(Gh_id !='Na')  %>% #select(Gh_id) %>%  
  st_set_geometry(NULL)

#NAM_stations_in_affected_areas<-NMA_stations %>% filter(apply(st_within( x =NMA_stations ,y = impact_data1_Z, sparse = FALSE), 1, any))
# filter(t_in='TRUE')
NMA_stations_<- NMA_stations %>% filter(Gh_id %in% NAM_stations_in_affected_areas$Gh_id)

hyd_stations_in_affected_areas<-st_intersection(eth_hydro_st,impact_data1_Z) %>% filter(SITE !='Na')  %>% #select(Gh_id) %>%  
  st_set_geometry(NULL)
eth_hydro_st_<- eth_hydro_st %>% filter(SITE %in% hyd_stations_in_affected_areas$SITE)



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

#write.csv(eth_hydro_st_,  "C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/data/Eth_hydro_selected_stations.csv", row.names = FALSE)
#write.csv(eth_glofas_st,"C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/input/Eth_affected_area_stations.csv", row.names = FALSE)

