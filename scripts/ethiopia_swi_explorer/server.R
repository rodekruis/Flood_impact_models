server <- function(input, output) {
  selected_pcode <- reactive({
    df_impact_raw %>%
      filter(!is.na(pcode)) %>%
      filter(wereda == input$wereda) %>%
      head(1) %>% pull(pcode)
  })

  df_impact <- reactive({
    df_impact_raw %>%
      filter(pcode == selected_pcode(),
             date >= input$dateRange[1],
             date <= input$dateRange[2])
  })

  swi <- reactive({
    swi_raw %>%
      filter(pcode == selected_pcode(),
             date >= input$dateRange[1],
             date <= input$dateRange[2])
  })

  output$swi_plot <- renderPlotly({
    p <- plot_swi(swi(), df_impact())
    p
  })

  output$flood_table <- DT::renderDataTable({
    most_impact_raw
  })
}

