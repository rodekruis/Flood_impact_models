library(shiny)
library(janitor)
library(tidyverse)
library(lubridate)
library(plotly)
library(shinydashboard)
library(sf)
library(leaflet)

source('r_resources/plot_functions.R')
source('r_resources/predict_functions.R')

# swi <- read.csv("data/ethiopia_admin3_swi_all.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric", "numeric", "numeric"))
ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")
rainfall_raw <- read_csv("data/ethiopia_admin3_rainfall.csv")
eth_admin3 <- sf::read_sf("shapes/ETH_adm3_mapshaper.shp")
eth_admin3 <- st_transform(eth_admin3, crs = "+proj=longlat +datum=WGS84")

glofas_raw <- read_csv("data/GLOFAS_fill_allstation.csv") %>% rename(date = time)
glofas_mapping <- read.csv("data/Eth_affected_area_stations.csv", stringsAsFactors = F)

# Clean impact and keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = i_region) %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

# Clean GLOFAS mapping
glofas_mapping <- glofas_mapping %>%
  dplyr::select(-Z_NAME) %>%
  gather(station_i, station_name, -W_NAME) %>%
  filter(!is.na(station_name)) %>%
  dplyr::select(-station_i) %>%
  left_join(ethiopia_impact %>% dplyr::select(Wereda, pcode) %>% unique(), by = c("W_NAME" = "Wereda")) %>%
  mutate(pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  filter(!is.na(pcode))

# Clean glofas
glofas_raw <- glofas_raw %>%
  filter(
    date >= min(df_impact_raw$date, na.rm=T) - 60,
    date <= max(df_impact_raw$date, na.rm=T) + 60)

# Used to join against
all_days <- tibble(date = seq(min(df_impact_raw$date, na.rm=T) - 60, max(df_impact_raw$date, na.rm=T) + 60, by="days"))

# Clean rainfall
rainfall_raw <- rainfall_raw %>%
  mutate(pcode = str_pad(pcode, 6, "left", 0)) %>%
  filter(
    date >= min(df_impact_raw$date, na.rm=T) - 60,
    date <= max(df_impact_raw$date, na.rm=T) + 60)

# # Clean SWI data
# swi_raw <- swi %>%
#   mutate(date = ymd(date))
#
# swi_raw <- swi_raw %>%
#   gather(depth, swi, -pcode, -date)

# Determine floods per Wereda for map
floods_per_wereda <- df_impact_raw %>%
  group_by(region, wereda, pcode) %>%
  summarise(
    n_floods = n()
  ) %>%
  arrange(-n_floods) %>%
  ungroup()

eth_admin3 <- eth_admin3 %>%
  left_join(floods_per_wereda %>% dplyr::select(pcode, n_floods), by = c("WOR_P_CODE" = "pcode"))

flood_palette <- colorNumeric(palette = "YlOrRd", domain = floods_per_wereda$n_floods)
