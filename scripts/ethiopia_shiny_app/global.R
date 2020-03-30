library(shiny)
library(janitor)
library(tidyverse)
library(lubridate)
library(plotly)
library(shinydashboard)
library(sf)
library(leaflet)
library()

source('r_resources/plot_functions.R')
source('r_resources/predict_functions.R')

swi <- read.csv("data/ethiopia_admin3_swi_all.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric", "numeric", "numeric"))
ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")
eth_admin3 <- sf::read_sf("shapes/ETH_adm3_mapshaper.shp")
eth_admin3 <- st_transform(eth_admin3, crs = "+proj=longlat +datum=WGS84")

swi_raw <- swi %>%
  mutate(date = ymd(date))

swi_raw <- swi_raw %>%
  gather(depth, swi, -pcode, -date)

# Clean ethiopia impact
ethiopia_impact <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = i_region) %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0"))

# Filter on available data in swi, keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  filter(date > "2007-01-01") %>%
  filter(pcode %in% swi$pcode) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

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

# Used to extend SWI
all_days <- data.frame(date = seq(ymd('2007-01-01'), ymd('2018-12-31'), by="days"))
