all_data <- read.csv('data/Impact_Hazard_catalog.csv',sep=';')

ui <- fluidPage(
  titlePanel("Impact Hazard data Exploration"),
  h1("Input Fields"),
  selectInput("Zone", "Zone", choices = levels(all_data$Zone), selected="Afar Zone 1"),
  dateRangeInput('dateRange',
                 label = 'Date range input: yyyy-mm-dd',
                 start = '2000-01-01', end = '2019-06-01'
  ),
  h2("Impact"),
  plotlyOutput("impact_plot"),
  h2("Available Glofas Points"),
  plotlyOutput("glofas_plot"),
  h2("Cumulative Rainfall"),
  plotlyOutput("rainfall_cums_plot"),
  h2("Rainfall"),
  plotlyOutput("rainfall_plot")

)