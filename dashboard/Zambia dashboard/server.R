#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#

# Define server logic 
shinyServer(function(input, output, session) {
  
  
  #reactive source: code receivers/input ---------------------------------------------------------------------
  input_station <- reactive({station_locations[which(station_locations$St_Name==input$station),]})
  input_score <- reactive({input$score})
  input_treshold_fwd_station <- reactive({df_stats_join[df_stats_join$threshold == input$threshold
                                                        & df_stats_join$fwd_looking == input$fwd_looking
                                                        & df_stats_join$station == input$station,]})
  input_province <- reactive({zmb_adm2[zmb_adm2$NAME_1 %in% input$province,]})
  input_district <- reactive({zmb_adm2[zmb_adm2$NAME_2 %in% input$district,]})
  
  input_best_performing_station <- reactive({df_stats_join %>% filter(threshold == input$threshold
           & fwd_looking == input$fwd_looking
           & region == input$district) %>% filter(Performance == max(Performance))})
  
  # create the map ----------------------------------------------------------------------------------------
  output$plot <- renderLeaflet({
    
    # set input parameters;     # use the aesthetic/argument to help uniquely identify selected observations
    map <- leaflet() %>%
      addTiles() %>%
      addTiles(urlTemplate = "//{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
               group = "OSM (default)") %>%
      addTiles(urlTemplate = "//{s}.tiles.mapbox.com/v3/jcheng.map-5ebohr46/{z}/{x}/{y}.png",
               attribution = 'Maps by <a href="http://www.mapbox.com/">Mapbox</a>',
               group = "Mapbox") %>%
      addProviderTiles(providers$OpenStreetMap.BlackAndWhite, group = "OSM (B&W)") %>%
      addMapPane("boundaries", zIndex = 410) %>%
      addMapPane("water", zIndex = 420) %>%
      addPolygons(data = zmb_adm2, stroke = TRUE, weight = 1, color = "black",
                  fill = TRUE, fillColor = "white", fillOpacity = 0.4,
                  popup = paste("<b>", "Information", "<br></b>",
                                "Country:", zmb_adm2$NAME_0, "<br>",
                                "Province:", zmb_adm2$NAME_1, "<br>",
                                "District:", zmb_adm2$NAME_2, "<br>")) %>%
      addPolylines(data = zmb_waterways, group = "Waterways", stroke = TRUE
                   , color = "black", weight = 0.8, opacity = 0.8, smoothFactor = 1
                   ,options = pathOptions(pane = "water")) %>%
      # addPolylines(data = zmb_waterways_small, group = "Waterways_small", stroke = TRUE
      #              , color = "blue", weight = 0.8, opacity = 0.8, smoothFactor = 1
      #              ,options = pathOptions(pane = "water")) %>%
      addLayersControl(position = "topleft",
                       baseGroups = c("OSM (default)", "Mapbox", "OSM (B&W)"),
                       overlayGroups = c("Waterways", "Waterways_small"),
                       options = layersControlOptions(collapsed = TRUE)) %>%
      addMeasure(position = "bottomleft",
                 primaryLengthUnit = "meters",
                 primaryAreaUnit = "sqmeters",
                 activeColor = "#3D535D",
                 completedColor = "#7D4479") 
  })
  
  # reactive endpoint: creates temp layers  --------------------------------------------------------------
  # reactive endpoint: input station > to display marker 
  observe({
    input_stat <- input_station()
    leafletProxy("plot", data = input_station())  %>% 
      clearMarkers() %>% 
      addAwesomeMarkers(~lon, ~lat, popup = ~htmlEscape(input_stat$St_Name))
  })
  
  # reactive endpoint: input province > to display province polygon 
  observe({
    leafletProxy("plot") %>%
      clearGroup("adm1 filter") %>%
        addPolygons(data = input_province(), stroke = TRUE, weight = 5, color = "black",
                fill = TRUE, fillColor = "white", fillOpacity = 0,
                group = "adm1 filter",
                popup = paste("<b>", "Information", "<br></b>",
                              "Country:", zmb_adm2$NAME_0, "<br>",
                              "Province:", zmb_adm2$NAME_1, "<br>",
                              "District:", zmb_adm2$NAME_2, "<br>"))
    })
  
  # # stukje kak - wat niet werkt
  # observe({
  #   input_best_performing_station = input_best_performing_station()
  #   input_best_performing_station_location <- station_locations %>% filter(St_Name == input_best_performing_station$station)
  #   leafletProxy("plot")  %>%
  #     clearMarkers() %>%
  #     clearGroup("adm1 filter") %>%
  #     addAwesomeMarkers(data = input_best_performing_station_location,
  #                       lng = ~lon, lat = ~lat)
  # })
  # 
  # # ander stukje kak - dat ook niet werkt
  # observe({
  #   leafletProxy("plot")  %>%
  #     clearMarkers() %>%
  #     clearGroup("adm1 filter") %>%
  #     addAwesomeMarkers(data = input_best_performing_station(),
  #                       lng = ~lon, lat = ~lat)
  # })
  # 
  
  # reactive endpoint: input district > to display district polygon 
  observe({
    leafletProxy("plot") %>%
      clearGroup("adm1 filter") %>%
      addPolygons(data = input_district(), stroke = TRUE, weight = 5, color = "black",
                  fill = TRUE, fillColor = "white", fillOpacity = 0,
                  group = "adm1 filter",
                  popup = paste("<b>", "Information", "<br></b>",
                                "Country:", zmb_adm2$NAME_0, "<br>",
                                "Province:", zmb_adm2$NAME_1, "<br>",
                                "District:", zmb_adm2$NAME_2, "<br>"))
  })
  
  # reactive endpoint: input score and treshold_station > to display choropleth per score 
  observe({
    
    # create labels for reactive polygons
    input_treshold_fwd_station <- input_treshold_fwd_station()
    

  
    #  ---------- Performance --------------------------------  
    
    leafletProxy("plot") %>%
      clearGroup("value") %>%
      
      addPolygons(
        data = input_treshold_fwd_station, group = "value", fillColor = ~Performance_pal(Performance),
        weight = 2, opacity = 0.7, color = "white", dashArray = "3", fillOpacity = 0.7,
        highlight = highlightOptions(weight = 2, color = "#666", dashArray = "", fillOpacity = 0.7, bringToFront = TRUE),
        options = pathOptions(pane = "boundaries"),
        label = paste("<b>", input_treshold_fwd_station$region, "<br></b>",
                      "Treshold:", input$threshold, "<br>",
                      "Days looking forward:", input$fwd_looking, "<br>",
                      # "CSI:", input_treshold_fwd_station$CSI, "<br>",
                      "Performance:", input_treshold_fwd_station$Performance, "<br>",
                      #  "FAR:", input_treshold_fwd_station$FAR, "<br>",
                      "Years hit:", input_treshold_fwd_station$hit_years, "<br>",
                      "Years missed:", input_treshold_fwd_station$missed_years, "<br>",
                      "Years false alarm:", input_treshold_fwd_station$fa_years, "<br>") %>% lapply(htmltools::HTML)
      ) %>%
      addLegend(data = input_treshold_fwd_station, pal = Performance_pal, values = ~Performance, opacity = 0.7, title = NULL,
                position = "bottomright", group = "value", layerId = "will_overwrite_legend")
    
    
    
    
  })
})

