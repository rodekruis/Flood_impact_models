all_data <- read.csv('data/prepped_data.csv')

ui <- fluidPage(
  titlePanel("Rainfall Data Exploration"),
  h1("Input Fields"),
  selectInput("district", "District", choices = levels(all_data$district), selected="KATAKWI"),
  dateRangeInput('dateRange',
                 label = 'Date range input: yyyy-mm-dd',
                 start = '2000-01-01', end = '2019-06-01'
  ),
  h2("(Shifted) Rainfall"),
  plotlyOutput("rainfall_shifts_plot"),
  h2("Cumulative Rainfall"),
  plotlyOutput("rainfall_cums_plot"),
  h2("Available Glofas Points"),
  plotlyOutput("glofas_plot")
)