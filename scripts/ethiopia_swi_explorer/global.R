library(shiny)
library(janitor)
library(tidyverse)
library(lubridate)
library(plotly)

source('r_resources/plot_functions.R')

swi <- read.csv("data/ethiopia_admin3_swi_all.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric", "numeric", "numeric"))
ethiopia_impact <- read.csv("data/Eth_impact_data.csv", stringsAsFactors = F, sep=";")

swi_raw <- swi %>%
  mutate(date = ymd(date))

swi_raw <- swi_raw %>%
  gather(depth, swi, -pcode, -date)

# Clean ethiopia impact
ethiopia_impact <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = i_region) %>%
  mutate(date = dmy(date))

# Filter on available data in swi, keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  filter(date > "2007-01-01") %>%
  filter(pcode %in% swi$pcode) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

most_impact_raw <- df_impact_raw %>%
  group_by(region, wereda, pcode) %>%
  summarise(
    n_floods = n()
  ) %>%
  arrange(-n_floods)