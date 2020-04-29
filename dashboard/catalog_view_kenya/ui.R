all_data <- read.csv('C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/dashboard/catalog_view_kenya/data/Impact_Hazard_catalog.csv',sep=';')

  
ui <- fluidPage(
  titlePanel("Impact Hazard data Exploration"),
  h1("Input Fields"),
  selectInput("County", "County", choices = levels(all_data$County), selected="Embu"),
  dateRangeInput('dateRange',
                 label = 'Date range input: yyyy-mm-dd',
                 start = '2000-01-01', end = '2019-06-01'
  ),
  h2("Impact"),
  plotlyOutput("impact_plot"),
  h2("Available Glofas Points"),
  plotlyOutput("glofas_plot")
  )
