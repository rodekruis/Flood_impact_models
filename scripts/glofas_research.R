library(purrr)
library(zoo)

source('scripts/prepare_glofas_data.R')

# Read and prep glofas files
glofas_data <- prep_glofas_data("uganda")

# Exploratotory analysis
glofas_data %>%
  group_by(station) %>%
  summarise(amount = n(),
            avg = mean(dis))

# Glofas data is not available for every date so make a complete calendar and fill missings
glofas_filled <- tibble(date = seq(min(glofas_data$date), max(glofas_data$date), by = "1 day"))
glofas_filled <- merge(glofas_filled, tibble(station = unique(glofas_data$station)))

glofas_filled <- glofas_filled %>%
  left_join(glofas_data, by = c("station", "date")) %>%
  arrange(station, date) %>%
  mutate(dis_filled = na.locf(dis))

# read the stations per region and gathered impact data
glofas_with_regions <- read_csv('raw_data/uganda/glofas_with_regions.csv')

impact_data <- read_csv("raw_data/uganda/own_impact_data.csv")

impact_data <- impact_data %>%
  mutate(date = as_date(Date),
         district = Area,
         flood = 1) %>% 
  dplyr::select(-Date, -Area)

# ------------------- Plots per station -----------------------------
pdf("output/uganda/flood_per_station.pdf", width=11, height=8.5)

for (station in unique(glofas_with_regions$station)) {
  districts <- glofas_with_regions %>% 
    filter(station == !!station) %>%
    dplyr::select(district) %>%
    pull()
  
  floods <- impact_data %>%
    filter(district %in% districts) %>%
    dplyr::select(district, date, certainty = Certainty, impact = Impact)
  
  plot_data <- glofas_filled %>%
    filter(station == !!station) %>%
    left_join(floods, by = "date") %>%
    mutate(label = ifelse(!is.na(district), paste(district, certainty), NA),
           dis = replace_na(dis, 0))
  
  p <- plot_data %>%
    ggplot(aes(x = date, y = dis)) + geom_line() + geom_label(aes(y=dis_filled, label=label)) +
    ggtitle(station) + theme(plot.title = element_text(hjust = 0.5, size = 16))
  print(p)
}

dev.off()

# ------------------- Plots per flood ----------------
impact_sub <- impact_data %>%
  filter(district %in% glofas_with_regions$district) %>%
  arrange(district, date)

pdf("output/uganda/stations_per_flood.pdf", width=11, height=8.5)

for (i in 1:nrow(impact_sub)) {
  flood_date <- impact_sub[i, ]$date
  district <- impact_sub[i, ]$district
  certainty <- impact_sub[i, ]$Certainty
  impact <- impact_sub[i, ]$Impact
  people <- impact_sub[i, ]$`People Affected`
  
  # Create description for top of plot
  description <- paste0(
    "Date: ", flood_date, "\n",
    "District: ", district, "\n",
    "Impact: ", impact, "\n",
    "Certainty: ", certainty, "\n",
    "People Affected: ", people
  )
  
  # Filter rainfall data 
  date_from <- flood_date - 60
  date_to <- flood_date + 60
  
  stations <- glofas_with_regions %>%
    filter(district == !!district) %>%
    dplyr::select(station) %>%
    pull()
  
  plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n')
  text(x = 0.5, y = 0.5, description, cex = 3, col = "black")
  
  plot_data <- glofas_filled %>%
    filter(station %in% stations) %>%
    filter(date <= date_to,
           date >= date_from) %>%
    left_join(impact_sub[i, ] %>%
                dplyr::select(date, flood)
              , by = "date")

  p <- ggplot(plot_data, aes(x = date)) + geom_line(aes(y = dis_filled)) + geom_point(aes(y = flood * dis_filled), color = "red") + facet_wrap(~station)
  print(p)
  
  plot_data2 <- glofas_filled %>%
    filter(station %in% stations) %>%
    left_join(impact_sub[i, ] %>%
                dplyr::select(date, flood)
              , by = "date")
  q <- ggplot(plot_data2, aes(x = date)) + geom_line(aes(y = dis_filled)) + geom_point(aes(y = flood * dis_filled), color = "red") + facet_wrap(~station)
  print(q)
}

dev.off()
