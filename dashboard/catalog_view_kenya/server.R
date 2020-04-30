library(shiny)
library(readr)
library(lubridate)
library(tidyr)
library(plotly)
library(ggplot2)
library(dplyr)

source('C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/dashboard/catalog_view_kenya/r_resources/plot_functions.R')

all_data <- read.csv('C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/dashboard/catalog_view_kenya/data/Impact_Hazard_catalog.csv',sep=';') %>%
  mutate(date = as_date(Date))
  
server <- function(input, output) {
  df <- reactive({
    filtered_data <- all_data %>%
      filter(County == input$County,
             date > input$dateRange[1],
             date < input$dateRange[2])
    return(filtered_data)
  })
  
  output$impact_plot <- renderPlotly({
    p <- plot_impact(df())
    p
  })
  output$glofas_plot <- renderPlotly({
    p <- plot_glofas(df())
    p
  }) 

}
