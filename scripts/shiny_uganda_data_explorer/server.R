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

