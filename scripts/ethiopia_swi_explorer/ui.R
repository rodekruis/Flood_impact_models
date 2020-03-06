ui <- fluidPage(
  titlePanel("SWI Data Exploration"),
  sidebarLayout(
    sidebarPanel(
      selectInput("wereda", "Wereda", choices = unique(df_impact_raw$wereda), selected="Alamata"),
      dateRangeInput('dateRange',
                     label = 'Date range input: yyyy-mm-dd',
                     start = '2007-01-01', end = '2020-01-01'
      )
    ),
    mainPanel(
      plotlyOutput("swi_plot"),
      DT::dataTableOutput("flood_table")
    )
  )
)