install.packages(c("maps", "ncdf4"))
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
library(sf)
#---------------------- Load inmpact data -------------------------------
# setwd(dirname(rstudioapi::getSourceEditorContext()$path))


crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

country_settings <- list(
  "uganda" = list("catchment_id_column" = "pcode"),
  "Ethiopia" = list("catchment_id_column" = "pcode",
                    "catchment_id_column" = "HYBAS_ID"),
  "kenya" = list(
    "boundary_shape_path" = "shapes/kenya_adm1/KEN_adm1_mapshaper_corrected.shp",
    "boundary_layer_name" = "KEN_adm1_mapshaper_corrected",
    "catchment_shape_path" = "shapes/kenya_catchment/Busa_catchment.shp",
    "catchment_layer_name" = "Busa_catchment",
    "catchment_id_column" = "HYBAS_ID") 
)

catchment_extraction_settings <- list(
  "admin_identifier" = "REG_Pcode",
  "output_folder" = "shapes/catchments/ethiopia_admin1",
  "output_filename" = "ethiopia_admin1_catchments.shp"
)


# Load in rainfall dataset 
#impact_data <- read.delim("data/Flood_impact.csv",sep=';',fileEncoding="UTF-8-BOM")

impact_data <- read.delim("raw_data/Ethiopia/Eth_impact_data2.csv",sep=';',fileEncoding="UTF-8-BOM")



#GEO_coast_altitude            ,

impact_data1 <- impact_data %>% dplyr::mutate(len_pcode= nchar(pcode)) %>%
  dplyr::mutate(Pcode= ifelse(len_pcode ==5, paste0("ET0", pcode), paste0("ET", pcode))) %>% 
  dplyr::select(-c(directely.affected,Indirectly.Affected,Relocated,Houses.Destroyed,Injured,Deaths,pcode,len_pcode))

impact_data1_1 <- impact_data1 %>%
  mutate(date = as.Date(Date, format="%d/%m/%Y"),
         district = Zone,
         flood = 1) #%>% dplyr::select(-Region)

#%>%    left_join(aggregate(Lost.Cattle ~ Region, impact_data1,sum), by = "Region")



#impact_data1 <- impact_data1 %>%  dplyr::mutate(com_in=Affected_pop*Frequency)

#---------------------- Load shape files data -------------------------------  

url <- parse_url("https://geonode.510.global/geoserver/geonode/ows")

#url <- parse_url("https://geonode.510.global/geoserver/ows")
#rivers <- st_read(dsn=settings$river_folder, layer=settings$river_layer)
###... RIVERS

url$query <- list(service = "WFS",
                  version = "2.0.0",
                  request = "GetFeature",
                  typename = "geonode:af_riv_15s", # rivers layer name
                  outputFormat = "application/json")
request <- build_url(url)
rivers <- st_read(request)


# Read in the admin shapes of interest, keep their identifier and filter out invalid geometries
#admin_shapes <- st_read(dsn=settings$admin_folder, layer=settings$admin_layer)

###.. admin boundary

url$query <- list(service = "WFS",
                  version = "2.0.0",
                  request = "GetFeature",
                  typename = "geonode:eth_admin3_2019", # admin_  layer name
                  outputFormat = "application/json")
request <- build_url(url)
admin_shapes <- st_read(request)

###... catchments

url$query <- list(service = "WFS",
                  version = "2.0.0",
                  request = "GetFeature",
                  typename = "geonode:hybas_af_lev12_v1", # basin layer name
                  outputFormat = "application/json")
request <- build_url(url)
basins_africa <- st_read(request)



admin_shapes <- admin_shapes %>%filter(st_is_valid(geometry))

admin_shapes1 <- st_transform(admin_shapes, st_crs(basins_africa))

admin_shapes <- admin_shapes %>% dplyr::mutate(Pcode=NewPCODE,wereda=W_NAME) %>% select(R_NAME,Z_NAME,W_NAME,wereda,Pcode,geometry)


#############################

impact_admin3<-admin_shapes %>%left_join(impact_data1_1 %>%mutate(year = substr(Date, 7, 10)),by="Pcode") %>%
  dplyr::select(R_NAME,Region,W_NAME,Wereda,Z_NAME,Zone,Date,Affected,year,Crop.Damages,Lost.Cattle,Pcode,geometry) %>% drop_na(Date)

 

m1 <- tm_shape(impact_admin3) + 
  tm_polygons("Affected") +
  tm_facets(along = "year")



# tmap
tmap_mode(mode = "plot")
m1 <- tm_shape(admin_shapes) + tm_borders(lwd = .5,col='#bdbdbd') +
  tm_shape(impact_admin3) + tm_polygons(col = "Affected", name='W_Name',
                                       palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                       breaks=c(0,5,1000,5000,20000,50000,90000),colorNA=NULL,
                                       labels=c('< 5','5 - 1k','1k - 5k','5k - 20k','20k - 50k','50k - 90k'),
                                       title="No of Affected People",
                                       border.col = "black",lwd = 0.5,lyt='dotted')+
  
  tm_facets(along = "year",free.coords = FALSE) +tm_format("World_wide")  #+   tm_format("NLD")


tmap_animation(m1, filename="Dutch_provinces4.gif", width=1600, delay=60)










data(World, metro)

m2 <- tm_shape(World, simplify = 0.5) +
  tm_fill() +
  tm_shape(metro) + 
  tm_bubbles(size = paste0("pop", seq(1970, 2030, by=10)),
             col = "purple",
             border.col = "black", border.alpha = .5,
             scale = 2) +
  tm_facets(free.scales.symbol.size = FALSE, nrow=1,ncol=1) + 
  tm_format("World", scale=.5)

tmap_animation(m2, filename="World population.gif", width=1200, delay=100)

c('#f0f0f0','#bdc9e1','#74a9cf','#2b8cbe','#045a8d')



river_eth <- st_intersection(rivers, eth_admin3) %>% filter(UP_CELLS>1500) ##arrange(desc(UP_CELLS)) %>% dplyr::select(ARCID,geometry)

river_eth <-river_eth %>% filter(UP_CELLS>7500)
#LOAD gLOFAS STATION

url$query <- list(service = "WFS",
                  version = "2.0.0",
                  request = "GetFeature",
                  typename = "geonode:glofas_stations_africa", # name
                  outputFormat = "application/json")
request <- build_url(url)
glofas_st <- st_read(request)


url$query <- list(service = "WFS",
                  version = "2.0.0",
                  request = "GetFeature",
                  typename = "geonode:nam_stations", # name
                  outputFormat = "application/json")
request <- build_url(url)
NMA_stations <- st_read(request)


#LOAD ADMIN 2 BOUNDERY 
url$query <- list(service = "WFS",
                  version = "2.0.0",
                  request = "GetFeature",
                  typename = "geonode:eth_admin2_2019", # admin_  layer name
                  outputFormat = "application/json")
request <- build_url(url)
admin_zone <- st_read(request)


Eth_affected_area_stations_ZONE<-st_join(admin_zone, glofas_st) %>% filter(Stationnam !='Na') %>% mutate(station=Stationnam) %>%
  select(Z_NAME,W_NAME,station) %>%  st_set_geometry(NULL)



#---------------------- ggregate data for admin 2 admin 1 -------------------------------
impact_data1_w_ts<-eth_admin3[!duplicated(impact_admin3$Wereda), ] %>%
  left_join(impact_admin3, by = "Wereda")  


impact_data1_w<-eth_admin3[!duplicated(eth_admin3$Wereda), ] %>%
  left_join(aggregate(Affected ~ Wereda, impact_data1,sum), by = "Wereda") %>%  
  left_join(aggregate(Crop.Damages ~ Wereda, impact_data1,sum), by = "Wereda") %>%  
  left_join(aggregate(Lost.Cattle ~ Wereda, impact_data1,sum), by = "Wereda") 


impact_data1_Z<-eth_admin3[!duplicated(eth_admin3$Zone), ] %>% select(Region,R_NAME,Zone,Z_NAME)  %>%
  left_join(aggregate(Affected ~ Zone, impact_data1,sum), by = "Zone") %>%  
  left_join(aggregate(Crop.Damages ~ Zone, impact_data1,sum), by = "Zone") %>%  
  left_join(aggregate(Lost.Cattle ~ Zone, impact_data1,sum), by = "Zone")


impact_data1_R<-eth_admin3[!duplicated(eth_admin3$Region), ] %>% select(Region,R_NAME)  %>%
  left_join(aggregate(Affected ~ Region, impact_data1,sum), by = "Region") %>%  
  left_join(aggregate(Crop.Damages ~ Region, impact_data1,sum), by = "Region") %>%  
  left_join(aggregate(Lost.Cattle ~ Region, impact_data1,sum), by = "Region")


write.csv(impact_data1,"C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/data/Eth_impact_data.csv", row.names = FALSE)


eth_glofas_st<-Eth_affected_area_stations_ZONE %>% select(Z_NAME,station)  %>%
  left_join(impact_data1_w %>% select(Z_NAME,R_NAME,W_NAME), by = "Z_NAME") %>% filter(W_NAME!="NA") %>%
  select(Z_NAME,W_NAME,station) %>% dplyr::distinct_all()%>% 
  group_by(W_NAME) %>% 
  mutate(id = paste0("st",row_number())) %>%
  ungroup()  %>% 
  spread(id, station)


eth_glofas_st_zone<-Eth_affected_area_stations_ZONE %>% select(Z_NAME,station)  %>%
  left_join(impact_data1_w %>% select(Z_NAME,R_NAME,W_NAME), by = "Z_NAME") %>% filter(W_NAME!="NA") %>%
  select(Z_NAME,station) %>% dplyr::distinct_all()%>% 
  group_by(Z_NAME) %>% 
  mutate(id = paste0("st",row_number())) %>%
  ungroup()  %>% 
  spread(id, station)

write.csv(eth_glofas_st,"C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/ethiopia/statistical_model/input/Eth_affected_area_stations.csv", row.names = FALSE)

#plot


#---------------------- visualize the data  -------------------------------
  
#par(mfrow=c(2,3) )

par(mfrow = c(2,3), oma = c(0.15, 0.15, 0.15, 0.15),mai = c(1.5, .75, 0.75, 0.15))
#par(mar=c(5.5, 6.15, 4.15, 1.25)+0.6)
#par(mar=c(5.5, 4.5, 5.15, 2.25)+0.2)
#par(fig=c(0.1,0.8,0.1,0.8),mfrow=c(2,3))

barplot(impact_data1_R$Affected, names = impact_data1_R$R_NAME,
        las = 3, cex.axis = 1.0, cex.names = 1.2, ylab = " Total Number of affected People", cex.lab = 1.5, space = 0,
        col = "#fc9272",
        main = "Most affected Regions\n by #of affected people",
        cex.main = 1.7)

barplot(impact_data1_R$Crop.Damages, names = impact_data1_R$R_NAME,
        las = 3, cex.axis = 1.2, cex.names = 1.2, ylab = "Total Area of Crope Damage", cex.lab = 1.5, space = 0,
        col = "#fc9272",
        main = "Most affected Regions\n by Crope Damage",
        cex.main = 1.7)

barplot(impact_data1_R$Lost.Cattle, names = impact_data1_R$R_NAME,
        las = 3, cex.axis = 1.2, cex.names = 1.2, ylab = "Total Number of Lost Cattles", cex.lab = 1.5, space = 0,
        col = "#fc9272",
        main = "Most affected Regions\n by Lost Cattles",
        cex.main = 1.7)

#---------------------- plot the most affected woedas and zones ------------------------------- 

impact_data1_Z_<-impact_data1_Z  %>%   top_n(20,wt=Affected)
 

# plot 


#impact_data1<-impact_data1  %>%   arrange(Affected,Crop.Damages) #%>% top_n(20,wt=Affected_pop)
#par(mfrow=c(1,3) )

#par(mar=c(11.5, 4.5, 13.15, 2.25)+0.2)

barplot(impact_data1_Z_$Affected, names = paste0(impact_data1_Z_$Region,',',impact_data1_Z_$Zone),
        las = 3, cex.axis = 1, cex.names = 1, ylab = "Total No of people affected", cex.lab = 1.7, space = 0,
        col = "#fc9272",
        main = "Most affected Zones \n by #of affected people",
        cex.main =1.7)


barplot(impact_data1_Z_$Crop.Damages, names = paste0(impact_data1_Z_$Region,',',impact_data1_Z_$Zone),
        las = 3, cex.axis = 1.0, cex.names = 1, ylab = "Total Area of Crop damage", cex.lab = 1.7, space = 0,
        col = "#fc9272",
        main = "Most affected Zone \n by Crop Damage",
        cex.main =1.7)

barplot(impact_data1_Z_$Lost.Cattle, names = paste0(impact_data1_Z_$Region,',',impact_data1_Z_$Zone),
        las = 3, cex.axis = 1.0, cex.names = 1.0, ylab = "Total No of Lost Cattles", cex.lab = 1.7, space = 0,
        col = "#fc9272",
        main = "Most affected Zone\n by Lost Cattles",
        cex.main = 1.7)



#---------------------- spatial plot of the most affected woedas and zones ------------------------------- 




 

# tmap
tmap_mode(mode = "view")
tm_shape(impact_data1_w) + tm_polygons(col = "Affected", name='W_Name',
                                   palette=c('#fef0d9','#fdd49e','#fdbb84','#fc8d59','#e34a33','#b30000'),
                                   breaks=c(0,5,1000,5000,20000,50000,90000),colorNA=NULL,
                                   labels=c('< 5','5 - 1k','1k - 5k','5k - 20k','20k - 50k','50k - 90k'),
                                   title="No of Affected People",
                                   border.col = "black",lwd = 0.5,lyt='dotted')+
  tm_shape(glofas_st) + tm_symbols(size=0.5,border.alpha = 0.5,col='#045a8d') +
  tm_shape(river_eth) + tm_lines(lwd=1,alpha = 0.5,col='#74a9cf') +
  tm_shape(eth_admin3) + tm_borders(lwd = .5,col='#bdbdbd') + #+   tm_format("NLD")
  
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



 

