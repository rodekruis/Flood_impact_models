#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#


# Suggestion for new UI
shinyUI(
  navbarPage(
    #theme = "flatly", 
    title = "Flood Prediction",
    
    # Interactive Flood Prediction Map ----------------------------------------------------------------------------------------
    
    navbarMenu("Flood Prediction Map",
               
               ## Zambia #############
               tabPanel("Zambia",
                        div(class = "outer",
                            
                            tags$head(
                              # Include our custom CSS
                              includeCSS("style.css")
                            ),
                            
                            # If not using custom CSS, set height of leafletOutput to a number instead of percent
                            leafletOutput("plot", width = "100%", height = "100%"),
                            
                            # Shiny versions prior to 0.11 should use class = "modal" instead.
                            absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                                          draggable = TRUE, top = 60, left = "auto", right = 20, bottom = "auto",
                                          width = 330, height = "auto",
                                          
                                          h2("Filter"),
                                          selectInput("station", "Station name", sort(unique(station_locations$St_Name)), selectize = TRUE, multiple = FALSE),
                                          selectInput("threshold", "Threshold", c( "Please select a threshold",sort(unique(df_stats_join$threshold))), multiple = FALSE),
                                          selectInput("fwd_looking", "Days looking forward", c( "Please select number of days",sort(unique(df_stats_join$fwd_looking))), multiple = FALSE),
                                          # checkboxInput("waterways", label = "Waterways", value = FALSE),
                                          hr(),
                                         # h6("CSI = hits / (hits + misses + false alarms)"),
                                        #  h6("POD = hits / (hits + misses)"),
                                         # h6("FAR = false alarms / (false alarms + hits)"),
                                           # h6("Performance = 0.75*Recall + 0.25* Precision"),
                                          hr(),
                                          selectInput("province", "Province", sort(unique(zmb_adm2$NAME_1)), multiple = TRUE),
                                          selectInput("district", "District", sort(unique(zmb_adm2$NAME_2)), multiple = FALSE)
                                          
                            )
                            
                        )
               )
    ),
    
    # additional menu ------------------------------------------------------------------------------------------------------
    navbarMenu("More",
               tabPanel("Whatever"),
               "----",
               "Extra",
               tabPanel("FAQ")
    ),
    conditionalPanel("false", icon("crosshair"))
  )
  
)
