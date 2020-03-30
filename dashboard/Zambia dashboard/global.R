#
# Dashboard for visualizing Flood predictions versus actual observations based on different levels of triggers in extreme event scenario's for Zambia
#
# Install required packages
if (!require("plotly")) install.packages('plotly')
if (!require("ggplot2")) install.packages('ggplot2')
if (!require("sf")) install.packages('sf')
if (!require("maptools")) install.packages('maptools')
if (!require("maps")) install.packages('maps')
if (!require("mapproj")) install.packages('mapproj')
if (!require("shinyWidgets")) install.packages('shinyWidgets')
if (!require("leaflet")) install.packages('leaflet')

if (!require("raster")) install.packages('raster')
if (!require("tidyverse")) install.packages('tidyverse')
if (!require("janitor")) install.packages('janitor')
if (!require("leaflet.extras")) install.packages('leaflet.extras')
if (!require("htmltools")) install.packages('htmltools')
if (!require("htmlwidgets")) install.packages('htmlwidgets')
if (!require("shinydashboard")) install.packages('shinydashboard')

# load pacakges
library(shiny)
library(plotly)
library(ggplot2)
library(sf)
library(maptools)
library(maps)
library(mapproj)
library(shinyWidgets)
library(leaflet)

library(raster)
library(tidyverse)
library(janitor)
library(leaflet.extras)
library(htmltools)
library(htmlwidgets)
library(shinydashboard)
options(scipen = 999)

# --------------------------------------------------------------------------------
# Input parameters
weight <- 0.75

# ---------------------------------------------------------------------------------
# Load relevant data
# Load shp file admin level 2. 
zmb_adm2 <- sf::read_sf("data/zmb_adm/ZMB_adm2.shp")

# Load shp file waterways osm
# zmb_waterways <- sf::read_sf("data/zmb_water/gis_osm_waterways_free_1.shp")
zmb_waterways <- sf::read_sf("data/zmb_water/zmb_osm_waterway.shp")
# zmb_waterways <- sf::read_sf("data/zmb_water/zmb_osm_water.shp")

# load station_locations
station_locations <- read.csv("data/Glofas_loc.csv", header = TRUE, sep =";")

# load output from glofas model 
df <- read_csv("data/input_for_dashboard_limited.csv")

# create hits, misses and false_alarm columns
df <- df %>% mutate(
  hits = if_else( pred == 1 & truth == 1, 1, 0),
  misses = if_else( pred == 0 & truth == 1, 1, 0),
  false_alarm = if_else(pred == 1 & truth == 0, 1, 0),
  correct_rejection = if_else(pred ==0 & truth == 0, 1,0)
   )

# summarise and create columns for CSI, POD and FAR
df_stats <- df %>% 
  group_by(station, region, threshold, fwd_looking) %>%
  summarise(count = n(),
            hit_years = paste(sort(unique(if_else(hits == 1, year, NULL))),collapse=", "),
            miss_years = paste(sort(unique(if_else(misses == 1, year, NULL))),collapse=", "),
            fa_years = paste(sort(unique(if_else(false_alarm == 1, year, NULL))),collapse=", "),
            sum_misses = sum(misses),
            sum_hits = sum(hits),
            sum_false_alarm = sum(false_alarm),
            sum_correct_rejection = sum(correct_rejection)) %>%
  mutate(CR = round(sum_correct_rejection / (sum_correct_rejection + sum_false_alarm), digits = 2),
         Recall = round(sum_hits / (sum_hits + sum_misses),digits = 2),
         Performance = weight * Recall +  (1-weight) * CR)    %>%
  ungroup()

# not all regions match with NAME_2 >> solved this by changing the region names
# also there are more regions in the glofas output then in the zmb_adm2.... 103 vs 69
df_stats$region[df_stats$region == "Chienge (Chiengi)"] <- "Chiengi"
df_stats$region[df_stats$region == "Mpongwe"] <- "MPongwe" 
df_stats$region[df_stats$region == "Shang'ombo"] <- "Shangombo"

# merge df_stats with selection of columns from adm2 layer
df_stats_join <- df_stats %>% 
  inner_join(zmb_adm2, by = c("region" = "NAME_2")) %>%
  select(-c("ID_0", "ISO", "NAME_0", "ID_1", "ID_2", "HASC_2", "CCN_2", "CCA_2", "TYPE_2", "ENGTYPE_2", "NL_NAME_2", "VARNAME_2")) %>%
  inner_join(station_locations, by = c("station" = "St_Name")) %>%
  select(-c("ï..Glofas_ID"))

# make the df of class sf
df_stats_join <- st_as_sf(df_stats_join, sf_column_name = "geometry")

# create color palettes
#CSI_pal <- colorBin("Greens", domain = df_stats_join$CSI, bins = 5) # wellicht reverse = TRUE aan toevoegen
Performance_pal <- colorBin("Blues", domain = df_stats_join$Performance, bins = 5)
#FAR_pal <- colorBin("Oranges", domain = df_stats_join$FAR, bins = 5)



# key
#rsconnect::setAccountInfo(name='kv301091',
#                          token='FC3DD32AB6F281CAE33BA074141ECCF8',
#                          secret='LyYJVCreraFPyqtAFHkRc39U1mCM3a1+AhS0t4/N')
 

# test best performing station per region
best_performing_station =
  df_stats_join %>%
  filter(threshold == 90
         & fwd_looking == 0
         & region == "Chama") %>%
  filter(Performance == max(Performance))

station_locations %>% filter(St_Name == best_performing_station$station)
