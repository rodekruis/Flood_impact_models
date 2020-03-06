library(janitor)
library(tidyverse)
library(lubridate)
library(plotly)

swi <- read.csv("raw_data/Ethiopia/swi/ethiopia_admin3_swi.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric"))
ethiopia_impact <- read.csv("raw_data/Ethiopia/Eth_impact_data.csv", stringsAsFactors = F, sep=";")

ethiopia_impact <- clean_names(ethiopia_impact) %>% rename(region = i_region)

swi <- swi %>%
  mutate(date = ymd(date))

ethiopia_impact %>% str()

ethiopia_impact <- ethiopia_impact %>%
  mutate(date = dmy(date))

df_impact <- ethiopia_impact %>%
  filter(date > "2007-01-01") %>%
  filter(pcode %in% swi$pcode) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

df_impact %>%
  group_by(pcode) %>%
  summarise(
    n = n()
  ) %>%
  arrange(-n)

selected_pcode <- "010407"



p <- swi %>%
  filter(pcode == selected_pcode) %>%
  ggplot(aes(x=date, y=swi)) +
  geom_line() +
  geom_vline(data = df_impact %>% filter(pcode == selected_pcode), aes(xintercept = as.numeric(date)), col="red")

ggplotly(p)
