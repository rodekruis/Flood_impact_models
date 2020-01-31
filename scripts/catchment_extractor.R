library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(tmap)
library(maps)
library(httr)
library(sf)
library(lubridate)
library(zoo)
library(xts)
library(lubridate)
require(data.table)

##############################################
clip <- function(raster, shape) {
  raster_crop <- crop(raster,shape)
  raster_bsn <- mask(raster_crop,shape)
  return(raster_bsn)
}

##############################################

# extract catchment for an areae

catchment_extractor<-function(sample_admin,basin){
  #basin <- st_read(dsn='C:/documents/General_data/Basins/hydrosheds/African_basins',layer='hybas_lake_af_lev12_v1c')
  basin_check2 <- st_intersection(sample_admin, basin)# %>% arrange(desc(UP_AREA)) %>% dplyr::select(HYBAS_ID,geometry)
  pts = 
    
    basin_check <- st_touches(sample_admin, basin)# %>% arrange(desc(UP_AREA)) %>% dplyr::select(HYBAS_ID,geometry)
  basin_<-basin %>% dplyr::select(HYBAS_ID,geometry)
  datalist = list()
  
  for (j in 1:length(as.list( basin_check2$HYBAS_ID)))  { 
    i<- as.list( basin_check2$HYBAS_ID)[[j]]
    list_con<-c(i)
    item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID 
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    checker<-c()
    ii=1
    if (length(item) !=0){
      while (TRUE)
      {
        ii=ii+1
        if (length(item) !=0){
          for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID   #1
          list_con<-c( list_con , item[ ! item %in% list_con ] )}
          item <-list_con
          checker[[ii]]<-length(list_con)
          if ((length(checker)>4) &(checker[[ii]]==checker[[ii-1]]))
          {
            break
          }
        }
        
        
      }
      
    }
    
    #assign(paste("cat", as.character(j), sep = "_"), list_con)
    cachment<-assign(paste("cat", as.character(j), sep = "_"), basin_[basin_$HYBAS_ID %in% list_con,])
    
    dat <- data.frame(HYBAS_ID = j, geom = cachment$geometry)
    df = st_as_sf(dat)
    datalist[[j]] <- df # add it to your list
    
    
  }
  return(datalist)
  
}


#---------------------- Load admin boundary data -------------------------------  

eth_admin3 <- st_read(dsn='C:/documents/ethiopia/admin3',layer='admin3')
rivers <- st_read(dsn='C:/documents/General_data/Basins/hydrosheds/African_rivers',layer='af_riv_15s')
eth_admin3<-eth_admin3 %>%  dplyr::mutate(Pcode=NewPCODE) %>%  dplyr::select(Pcode,geometry)

region2<-extent(eth_admin3)

ethiopia_region = st_bbox(c(xmin =as.vector(region2@xmin), xmax = as.vector(region2@xmax),
                            ymin = as.vector(region2@ymin), ymax =as.vector(region2@ymax)),
                          crs = st_crs(eth_admin3)) %>% st_as_sfc()

basin <- st_read(dsn='C:/documents/General_data/Basins/hydrosheds/African_basins',layer='hybas_lake_af_lev12_v1c')


################################# run the code for sample admin 
sample_admin<-eth_admin3[1,]
cat_admin1<-catchment_extractor(sample_admin,basin)
item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID



