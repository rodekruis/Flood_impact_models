library(shiny)
library(readr)
library(lubridate)
library(tidyr)
library(plotly)
library(ggplot2)
library(dplyr)

source('r_resources/plot_functions.R')

all_data <- read.csv('data/shiny_explorer_input.csv') %>%
  mutate(date = as_date(date))
