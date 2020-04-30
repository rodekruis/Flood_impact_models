server <- function(input, output) {

  selected_pcode <- reactiveVal("020104")
  has_glofas <- reactiveVal(TRUE)

  glofas <- reactive({
    req(input$glofas_station_selected)

    all_days %>%
      left_join(glofas_raw %>% dplyr::select(date, dis, station) %>% filter(station == input$glofas_station_selected), by="date") %>%
      fill(dis, station, .direction="down") %>%
      fill(dis, station, .direction="up") %>%
      filter(date >= input$dateRange[1], date <= input$dateRange[2])
  })

  rainfall <- reactive({
    rainfall_raw %>%
      filter(
        pcode == selected_pcode(),
        date >= input$dateRange[1],
        date <= input$dateRange[2]
      )
  })

  impact_df <- reactive({
    df_impact_raw %>%
      filter(pcode == selected_pcode(),
             date >= input$dateRange[1],
             date <= input$dateRange[2])
  })

  # swi <- reactive({
  #   swi_raw %>%
  #     filter(pcode == selected_pcode(),
  #            date >= input$dateRange[1],
  #            date <= input$dateRange[2])
  # })

  # output$swi_plot <- renderPlotly({
  #   p <- plot_swi(swi(), df_impact(), input$swi_threshold)
  #   p
  # })

  output$rainfall_glofas_plot <- renderPlotly({
    p <- plot_rainfall_glofas(rainfall(), glofas(), impact_df(), input$rainfall_threshold, input$glofas_threshold, has_glofas())
    p
  })

  # result_table <- reactive({predict_with_swi(all_days, swi_raw, df_impact_raw, selected_pcode(), input$swi_threshold)})
  result_table <- reactive({predict_with_glofas_and_rainfall(all_days, rainfall(), glofas(), impact_df(), input$rainfall_threshold, input$glofas_threshold, has_glofas())})

  floods_val <- reactive({result_table() %>% pull(floods)})
  floods_correct_val <- reactive({result_table() %>% pull(floods_correct)})
  floods_incorrect_val <- reactive({result_table() %>% pull(floods_incorrect)})
  protocol_triggered_val <- reactive({result_table() %>% pull(protocol_triggered)})
  detection_ratio_val <- reactive({result_table() %>% pull(detection_ratio)})
  fals_alarm_ratio_val <- reactive({result_table() %>% pull(false_alarm_ratio)})

  output$result_html <- renderUI({
    HTML(
      paste0(
        '<span style="font-size:20px"> Floods: </span> ', floods_val(), "<br />",
        '<span style="font-size:20px"> Floods Correct: </span> ', floods_correct_val(), "<br />",
        '<span style="font-size:20px"> Floods Incorrect: </span> ', floods_incorrect_val(), "<br />",
        '<span style="font-size:20px"> Protocol Triggered: </span> ', protocol_triggered_val(), "<br />",
        '<span style="font-size:20px"> Detection Ratio: </span> ', detection_ratio_val(), "<br />",
        '<span style="font-size:20px"> False Alarm Ratio: </span> ', fals_alarm_ratio_val(), "<br />"
      )
    )
  })

  output$glofas_dropdown <- renderUI({
    station_options <- glofas_mapping %>%
      filter(pcode == selected_pcode()) %>%
      pull(station_name) %>% unique()

    if (length(station_options) > 0) {
      has_glofas(TRUE)
      selectInput("glofas_station_selected", "Select Glofas Station: ", choices=station_options)
    } else {
      has_glofas(FALSE)
      HTML("<h3> No Glofas stations available for this region </h3> <br />")
    }
  })

  output$glofas_slider <- renderUI({
    if(has_glofas()) {
      sliderInput("glofas_threshold", "Select Glofas Station Threshold: ", min=0, max = round(max(glofas()$dis, na.rm=T)), value=round(quantile(glofas()$dis, 0.95, na.rm=T)))
    } else {
      NULL
    }
  })

  output$rainfall_slider <- renderUI({
    sliderInput("rainfall_threshold", "Select Rainfall Threshold: ", min=0, max = round(max(rainfall()$rainfall, na.rm=T)), value=round(quantile(rainfall()$rainfall, 0.95, na.rm=T)))
  })

  output$impact_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$OpenStreetMap) %>%
      addPolygons(data = eth_admin3, label=~WOREDANAME, layerId=~WOR_P_CODE, col=~flood_palette(n_floods), fillOpacity=0.8, opacity = 1, weight=1.2)
  })

  observeEvent(input$impact_map_shape_click, {
    event <- input$impact_map_shape_click
    woreda_pcode <- event$id
    selected_pcode(woreda_pcode)

    if (is.null(event$id)) { return() }  # Do nothing if it is a random click

  })
}