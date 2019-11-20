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
catchment_extractor_old<-function(sample_admin){
  basin <- st_read(dsn='C:/documents/General_data/Basins/hydrosheds/African_basins',layer='hybas_lake_af_lev12_v1c')
  basin_check <- st_intersection(sample_admin, basin) %>% arrange(desc(UP_AREA)) %>% dplyr::select(HYBAS_ID,geometry)
  basin_<-basin %>% dplyr::select(HYBAS_ID,geometry)
  datalist = list()
  
  for (j in 1:length(as.list( basin_check$HYBAS_ID)))  { 
    i<- as.list( basin_check$HYBAS_ID)[[j]]
    list_con<-c(i)
    item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID 
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID   #1
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID  #2
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #4
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #5
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #6
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #7
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #8
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #9
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #10
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #11
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #12
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #13
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #14
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID #15
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    if(length(item) != 0) { for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID 
    list_con<-c( list_con , item[ ! item %in% list_con ] )    }}      }}      }}      }}      }}      }}      }}      }}      }}      }}      }}      }}      }}      }}     }     }

    cachment<-assign(paste("cat", as.character(j), sep = "_"), basin_[basin_$HYBAS_ID %in% list_con,])
    
    dat <- data.frame(HYBAS_ID = j, geom = cachment$geometry)
    df = st_as_sf(dat)
    datalist[[j]] <- df # add it to your list
      }
  return(datalist)
  
}
##########################################################

catchment_extractor<-function(sample_admin){
  basin <- st_read(dsn='C:/documents/General_data/Basins/hydrosheds/African_basins',layer='hybas_lake_af_lev12_v1c')
  basin_check <- st_intersection(sample_admin, basin) %>% arrange(desc(UP_AREA)) %>% dplyr::select(HYBAS_ID,geometry)
  basin_<-basin %>% dplyr::select(HYBAS_ID,geometry)
  datalist = list()
  
  for (j in 1:length(as.list( basin_check$HYBAS_ID)))  { 
    i<- as.list( basin_check$HYBAS_ID)[[j]]
    list_con<-c(i)
    item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID 
    list_con<-c( list_con , item[ ! item %in% list_con ] )
    while (length(item) != 0)
    {
      for (i in item){item<-basin[basin$NEXT_DOWN==i,]$HYBAS_ID   #1
      list_con<-c( list_con , item[ ! item %in% list_con ] )}
      
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

################################# run the code for sample admin 
sample_admin<-eth_admin3[1,]

cat_admin1<-catchment_extractor(sample_admin)


 
