library(shiny)
library(readr)
library(lubridate)
library(tidyr)
library(plotly)
library(ggplot2)

source('r_resources/plot_functions.R')

all_data <- read.csv('data/Impact_Hazard_catalog.csv',sep=';') %>%
  mutate(date = as_date(Date))

server <- function(input, output) {
  df <- reactive({
    filtered_data <- all_data %>%
      filter(Zone == input$Zone,
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
  output$rainfall_cums_plot <- renderPlotly({
    p <- plot_rainfall_cums(df())
    p
  })
  output$rainfall_plot <- renderPlotly({
    p <- plot_rainfall(df())
    p
  })

}
