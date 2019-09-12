library(shiny)
library(readr)
library(lubridate)
library(tidyr)
library(plotly)
library(ggplot2)

source('r_resources/plot_functions.R')

all_data <- read.csv('data/prepped_data.csv') %>%
  mutate(date = as_date(date))

server <- function(input, output) {
  df <- reactive({
    filtered_data <- all_data %>%
      filter(district == input$district,
             date > input$dateRange[1],
             date < input$dateRange[2])
    return(filtered_data)
  })

  output$rainfall_shifts_plot <- renderPlotly({
    p <- plot_rainfall_shifts(df())
    p
  })
  
  output$rainfall_cums_plot <- renderPlotly({
    p <- plot_rainfall_cums(df())
    p
  })
  
  output$glofas_plot <- renderPlotly({
    p <- plot_glofas(df())
    p
  })
}

# all_data <- read.csv('shiny_app/data/prepped_data.csv') %>%
#   mutate(date = as_date(date))
# 
# df <- all_data %>%
#   filter(district == "KATAKWI")
# 
# df %>%
#   summary()
#   select_if(~sum(!is.na(.)) > 0) %>%
#   str()
#   select(date, contains('F0'))
# #%>%
#   drop_na() %>%
#   gather("var", "val", -date) %>%
#   ggplot(aes(x=date, y=val)) + geom_line() + facet_wrap(~var)
