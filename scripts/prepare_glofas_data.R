library(purrr)
library(tidyr)

prep_glofas_data <- function(){
  # Read glofas files
  glofas_files <- list.files('raw_data/glofas')
  glofas_stations <- str_match(glofas_files, '^(?:[^_]*_){3}([^.]*)')[,2]
  
  glofas_data <- map2_dfr(glofas_files, glofas_stations, function(filename, glofas_station) {
    suppressMessages(read_csv(file.path('raw_data', 'glofas', filename))) %>%
      mutate(station = glofas_station)
  })
  
  glofas_data <- glofas_data %>%
    rename(date = X1)
  
  return(glofas_data)
}

make_glofas_district_matrix <- function(glofas_data) {
  
  glofas_with_regions <- read_csv('raw_data/glofas_with_regions.csv')
  
  glofas_data <- glofas_data %>%
    left_join(glofas_with_regions, by="station") %>%
    spread(station, dis) %>%
    mutate(district = toupper(district)) %>%
    arrange(district, date)
  
  
  return(glofas_data)
}
