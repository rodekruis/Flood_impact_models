library(purrr)
library(tidyr)

prep_glofas_data <- function(country){
  # Read glofas files
  glofas_files <- list.files(file.path('raw_data', country, 'glofas'))
  glofas_stations <- str_match(glofas_files, '^(?:[^_]*_){3}([^.]*)')[,2]
  
  glofas_data <- map2_dfr(glofas_files, glofas_stations, function(filename, glofas_station) {
    suppressMessages(read_csv(file.path('raw_data', country, 'glofas', filename))) %>%
      mutate(station = glofas_station)
  })
  
  glofas_data <- glofas_data %>%
    rename(date = X1)
  
  return(glofas_data)
}


fill_glofas_data <- function(glofas_data){
  glofas_filled <- tibble(date = seq(min(glofas_data$date), max(glofas_data$date), by = "1 day"))
  glofas_filled <- merge(glofas_filled, tibble(station = unique(glofas_data$station)))
  
  glofas_filled <- glofas_filled %>%
    left_join(glofas_data, by = c("station", "date")) %>%
    arrange(station, date) %>%
    mutate(dis = na.locf(dis))
  
  return(glofas_filled)
}

make_glofas_district_matrix <- function(glofas_data, country) {
  
  glofas_with_regions <- read_csv(file.path('raw_data', country, 'glofas_with_regions.csv'))
  
  glofas_data <- glofas_data %>%
    left_join(glofas_with_regions, by="station") %>%
    spread(station, dis) %>%
    mutate(district = as.character(district))
  
  
  return(glofas_data)
}
