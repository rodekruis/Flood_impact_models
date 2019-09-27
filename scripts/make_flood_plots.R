library(rgdal)
library(maps)
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(stringr)
library(readxl)
library(ggplot2)
library(zoo)

source("scripts/create_rain_data.R")

# -------------------------- Settings --------------------------------------------------
rainfall_file_name <- file.path("raw_data", "uganda", "rainfall_catchment.csv")

#---------------------- Load in self gathered impact data -------------------------------
impact_data <- read_csv("raw_data/uganda/own_impact_data.csv")
impact_data <- impact_data %>%
  mutate(date = as_date(Date),
         district = str_to_upper(Area),
         flood = 1) %>% 
  dplyr::select(-Date, -Area)

#---------------------- Load and transform rain data -------------------------------
# Define projection: 
crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

# Load in rainfall dataset 
rainfall <- read.csv(rainfall_file_name) %>%
  mutate(date = as_date(date))

rainfall <- create_extra_rainfall_vars(rainfall)

make_plots <- function(gg_data, district, verbose=FALSE){
  plot_theme <- theme(axis.title.y = element_blank(),
                      plot.title = element_text(hjust = 0.5, size = 16))
  
  p_on_day <- gg_data %>%
    ggplot(aes(x = date)) + geom_line(aes(y = zero_shifts)) + geom_label(aes(y=flood*zero_shifts, label = paste(Impact, Certainty))) +
    ggtitle(paste(district, "Rain on day (mm)", sep = "-")) + plot_theme
  
  p_2_cum <- gg_data %>%
    ggplot(aes(x = date)) + geom_line(aes(y = rainfall_2days)) + geom_label(aes(y=flood*rainfall_2days, label = paste(Impact, Certainty))) +
    ggtitle(paste(district, "Cum. rain 2 days (mm)", sep = "-")) + plot_theme
  
  p_3_cum <- gg_data %>%
    ggplot(aes(x = date)) + geom_line(aes(y = rainfall_3days)) + geom_label(aes(y=flood*rainfall_3days, label = paste(Impact, Certainty))) +
    ggtitle(paste(district, "Cum. rain 3 days (mm)", sep = "-")) + plot_theme
  
  if (verbose) {
    p_1_day_before <- gg_data %>%
      ggplot(aes(x = date)) + geom_line(aes(y = one_shift)) + geom_label(aes(y=flood*one_shift, label = paste(Impact, Certainty))) +
      ggtitle(paste(district, "Rain 1 day before (mm)", sep = "-")) + plot_theme
    
    p_2_day_before <- gg_data %>%
      ggplot(aes(x = date)) + geom_line(aes(y = two_shifts)) + geom_label(aes(y=flood*two_shifts, label = paste(Impact, Certainty))) +
      ggtitle(paste(district, "Rain 2 days before (mm)", sep = "-")) + plot_theme
    
    p_3_day_before <- gg_data %>%
      ggplot(aes(x = date)) + geom_line(aes(y = three_shifts)) + geom_label(aes(y=flood*three_shifts, label = paste(Impact, Certainty))) +
      ggtitle(paste(district, "Rain 3 days before (mm)", sep = "-")) + plot_theme
    
    p_4_cum <- gg_data %>%
      ggplot(aes(x = date)) + geom_line(aes(y = rainfall_4days)) + geom_label(aes(y=flood*rainfall_4days, label = paste(Impact, Certainty))) +
      ggtitle(paste(district, "Cum. rain 4 days (mm)", sep = "-")) + plot_theme 
    
    plots <- list(p_on_day, p_1_day_before, p_2_day_before, p_3_day_before, p_2_cum, p_3_cum, p_4_cum)
  }else{
    plots <- list(p_on_day, p_2_cum, p_3_cum)    
  }
  return(plots)
}

make_flood_overview_pdf <- function(districts, pdf_name, from_date="20070101", to_date="20190701", verbose=FALSE){
  pdf(pdf_name, width=11, height=8.5)
  for (district in districts){
    gg_data <- rainfall %>%
      left_join(impact_data, by = c("district", "date")) %>%
      filter(district == !!district) %>%
      filter(date > as_date(!!from_date)) %>%
      filter(date < as_date(!!to_date))
    
    plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')    
    
    n_floods <- impact_data %>% filter(district == !!district) %>% nrow()
    
    if (!district %in% rainfall$district & (n_floods > 0)) {
      text(x = 0.5, y = 0.5, paste(district, "has", n_floods, "flood(s) but no catchment area available"), 
           cex = 2, col = "black")
      next()
    }
    
    # Break if there is no flood in range
    if (sum(gg_data$flood, na.rm = T) == 0) {
      text(x = 0.5, y = 0.5, paste(district, "has no floods in selected time range"), 
           cex = 2, col = "black")
      next()
    }
    
    # Break if there is no rainfall data
    if (nrow(rainfall %>% filter(district == !!district, !is.na(zero_shifts))) == 0) {
      text(x = 0.5, y = 0.5, paste(district, "has no rain data available"), 
           cex = 2, col = "black")
      next()
    }
    
    # Otherwise print district name and plots
    text(x = 0.5, y = 0.5, district, 
         cex = 3, col = "black")
    
    plots <- make_plots(gg_data, district, verbose)
    
    for (plot in plots) {
      print(plot)
    }
  }
  dev.off()
}

districts <- sort(unique(impact_data$district))

make_flood_overview_pdf(districts, "output/uganda/overview_per_district.pdf", verbose = FALSE)
make_flood_overview_pdf(districts, "output/uganda/overview_per_district_detailed.pdf", verbose = TRUE)

# Temporary solution, in the future we should just rename the lag columns to something sensible
rain_labels <- read_csv('raw_data/uganda/pretty_rain_labels.csv')

impact_data <- impact_data %>%
  arrange(district, date)

# Create zoomed in plots

make_zoomed_in_plots <- function(pdf_name){
  pdf(pdf_name, width=11, height=8.5)
  
  for (i in 1:nrow(impact_data)) {
    # Get data from row
    flood_date <- impact_data[i, ]$date
    district <- impact_data[i, ]$district
    certainty <- impact_data[i, ]$Certainty
    impact <- impact_data[i, ]$Impact
    people <- impact_data[i, ]$`People Affected`
    
    # Create description for top of plot
    description <- paste0(
      "Date: ", flood_date, "\n",
      "District: ", district, "\n",
      "Impact: ", impact, "\n",
      "Certainty: ", certainty, "\n",
      "People Affected: ", people
    )
    
    # Filter rainfall data 
    date_from <- flood_date - 30
    date_to <- flood_date + 30
    rainfall_sub <- rainfall %>%
      filter(district == !!district,
             date > date_from,
             date < date_to) %>%
      mutate(flood = ifelse(date == flood_date, TRUE, NA))
    
    # Filter if less than 30 rows because event is more in the future than rainfall data
    if (nrow(rainfall_sub) < 31) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no rain data available"), 
           cex = 3, col = "black")
      next()
    }
    
    # Filter if no weather data available
    if (nrow(rainfall_sub %>% filter(!is.na(zero_shifts))) == 0) {
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
      text(x = 0.5, y = 0.5, paste0(description, "\n", "no rain data available"), 
           cex = 3, col = "black")
      next()
    }

    # Make plot facetwrapped for each variable
    p <- rainfall_sub %>%
      dplyr::select(-pcode, -district, -flood) %>%
      gather(key = "rain_var", value = "value", -date) %>%
      left_join(rain_labels, by = "rain_var") %>%
      mutate(flood = ifelse(date == flood_date, TRUE, NA)) %>%
      ggplot(aes(x = date)) + geom_line(aes(y = value)) +
      geom_point(aes(y = value * flood), color = "red") + facet_wrap(~rain_var_pretty) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            plot.title = element_text(hjust = 0.5, size = 16)) +
      ggtitle(description)
    
    print(p)
  }
  
  dev.off() 
}

make_zoomed_in_plots("output/uganda/zoomed_in_per_flood.pdf")
