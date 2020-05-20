
selected_pcode <- "020104"
selected_station <- "G1045"
selected_lowdate <- "2000-07-19"
selected_highdate <- "2018-04-05"
rainfall_threshold <- 2
glofas_threshold <- 864

glofas <-glofas_raw %>%
    filter(station == selected_station) %>%
    filter(date >= selected_lowdate, date <= selected_highdate)

rainfall <- rainfall_raw %>%
    filter(
      pcode == selected_pcode,
      date >= selected_lowdate,
      date <= selected_highdate)

impact_df <- df_impact_raw %>%
    filter(pcode == selected_pcode,
           date >= selected_lowdate,
           date <= selected_highdate)

plot_rainfall_glofas(rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, TRUE)
predict_with_glofas_and_rainfall(all_days, rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, TRUE)

glofas %>%
  left_join(rainfall, by = "date") %>%
  left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
  mutate(
    flood = replace_na(flood, FALSE),
    rainfall_exceeds_threshold = rainfall >= rainfall_threshold,
    glofas_exceeds_threshold = dis >= glofas_threshold,
    both_exceed_threshold = rainfall_exceeds_threshold & glofas_exceeds_threshold,
    flood_correct = flood & both_exceed_threshold,
    next_exceeds_threshold = lag(both_exceed_threshold),
    peak_start = !both_exceed_threshold & next_exceeds_threshold
  ) %>%
  summarise(
    floods = sum(flood),
    floods_correct = sum(flood_correct),
    floods_incorrect = floods - floods_correct,
    protocol_triggered = sum(peak_start, na.rm=T),
    triggered_in_vain = protocol_triggered - floods_correct,
    triggered_correct = floods_correct,
    detection_ratio = round(floods_correct / floods, 2),
    false_alarm_ratio = round(triggered_in_vain/protocol_triggered, 2)
  )




source('r_resources/plot_functions.R')
source('r_resources/predict_functions.R')

# swi <- read.csv("data/ethiopia_admin3_swi_all.csv", stringsAsFactors = F, colClasses = c("character", "character", "numeric", "numeric", "numeric"))
ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")
# rainfall_raw <- read_csv("data/ethiopia_admin3_rainfall.csv")  # CHIRPS, kept for legacy
eth_admin3 <- sf::read_sf("shapes/ETH_adm3_mapshaper.shp")
eth_admin3 <- st_transform(eth_admin3, crs = "+proj=longlat +datum=WGS84")

glofas_raw <- read_csv("data/GLOFAS_fill_allstation.csv") %>% rename(date = time)
glofas_mapping <- read.csv("data/Eth_affected_area_stations.csv", stringsAsFactors = F)
point_rainfall <- read_csv('data/Impact_Hazard_catalog.csv') %>% clean_names()

# Used to join against
all_days <- tibble(date = seq(min(df_impact_raw$date, na.rm=T) - 60, max(df_impact_raw$date, na.rm=T) + 60, by="days"))

# Clean impact and keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = i_region) %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)

# Clean GLOFAS mapping
glofas_mapping <- glofas_mapping %>%
  dplyr::select(-Z_NAME) %>%
  gather(station_i, station_name, -W_NAME) %>%
  filter(!is.na(station_name)) %>%
  dplyr::select(-station_i) %>%
  left_join(ethiopia_impact %>% dplyr::select(Wereda, pcode) %>% unique(), by = c("W_NAME" = "Wereda")) %>%
  mutate(pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  filter(!is.na(pcode))

# Clean glofas
glofas_raw <- glofas_raw %>%
  filter(
    date >= min(df_impact_raw$date, na.rm=T) - 60,
    date <= max(df_impact_raw$date, na.rm=T) + 60)

glofas_raw <- expand.grid(all_days$date, unique(glofas_raw$station)) %>%
  rename(date = Var1, station = Var2) %>%
  left_join(glofas_raw %>% dplyr::select(date, dis, station), by = c("date", "station")) %>% arrange(station, date) %>%
  arrange(station, date) %>%
  group_by(station) %>%
  fill(dis, .direction="down") %>%
  fill(dis, .direction="up") %>%
  ungroup()

rainfall_raw <- point_rainfall %>%
  left_join(df_impact_raw %>% dplyr::select(pcode, zone), by = "zone") %>%
  group_by(pcode, date) %>%
  summarise(rainfall = mean(rainfall, na.rm=T))

# Clean rainfall - CHIRPS, kept for legacy
# rainfall_raw <- rainfall_raw %>%
#   mutate(pcode = str_pad(pcode, 6, "left", 0)) %>%
#   filter(
#     date >= min(df_impact_raw$date, na.rm=T) - 60,
#     date <= max(df_impact_raw$date, na.rm=T) + 60)

# # SWI, kept for legacy
# swi_raw <- swi %>%
#   mutate(date = ymd(date))
#
# swi_raw <- swi_raw %>%
#   gather(depth, swi, -pcode, -date)

# Determine floods per Wereda for map
floods_per_wereda <- df_impact_raw %>%
  group_by(region, wereda, pcode) %>%
  summarise(
    n_floods = n()
  ) %>%
  arrange(-n_floods) %>%
  ungroup()

eth_admin3 <- eth_admin3 %>% left_join(floods_per_wereda %>% dplyr::select(pcode, n_floods), by = c("WOR_P_CODE" = "pcode")) %>%
  filter(!is.na(n_floods))

flood_palette <- colorNumeric(palette = "YlOrRd", domain = floods_per_wereda$n_floods)
glofas2<- glofas %>% mutate(flood=ifelse(dis >= 500,1,0)) %>%  mutate(cum_sep_len = c(NA,diff(accumulate(glofas2$flood, ~ ifelse(.x >= 0, .y, .x + .y)))))

glofas2<- glofas2 %>% mutate( Return_aux = ifelse( is.na(flood), 0, flood ), Cum_Sum = cumsum(Return_aux) )

test <- c(9, 3, 2, 2, 8, 5, 4, 9, 1)

#cumsum(c(FALSE, 
diff(accumulate(glofas2$flood, ~ ifelse(.x >= 0, .y, .x + .y)))# <= 0))


# Clean impact and keep relevant columns
df_impact_raw <- ethiopia_impact %>%
  clean_names() %>%
  rename(region = ï..Region) %>%
  mutate(date = dmy(date),
         pcode = str_pad(as.character(pcode), 6, "left", "0")) %>%
  dplyr::select(region, zone, wereda, pcode, date) %>%
  unique() %>%
  arrange(pcode, date)
ethiopia_impact <- read.csv("data/Eth_impact_data2.csv", stringsAsFactors = F, sep=";")


