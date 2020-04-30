library(gridExtra)
library(grid)

selected_pcode <- '041107'

all_days %>%
  left_join(glofas_raw, by = "date")


# To put in reactive function

glofas_temp <- all_days %>%
  left_join(
    glofas_raw %>%
      filter(station %in% (glofas_mapping %>% filter(pcode == selected_pcode) %>% pull(station_name))) %>%
      dplyr::select(date, dis, station),
  by="date") %>%
  fill(dis, station, .direction="down") %>%
  fill(dis, station, .direction="up")

df_impact_raw_temp <- df_impact_raw %>%
  filter(pcode == selected_pcode)

rainfall_temp <- rainfall_raw %>%
  filter(pcode == selected_pcode)

rainfall_threshold <- 20
glofas_threshold <- 1000

p1 <- ggplot(rainfall_temp, aes(x=date, y = rainfall)) + geom_line(col='lightblue') +
  geom_hline(yintercept = rainfall_threshold) +
  geom_vline(data = df_impact_raw_temp, aes(xintercept = as.numeric(date)), col="red") +
  scale_y_continuous(trans = "reverse")

p2 <- ggplot(glofas_temp, aes(x=date, y = dis)) + geom_line(col='orange') +
  geom_vline(data = df_impact_raw_temp, aes(xintercept = as.numeric(date)), col="red") +
  geom_hline(yintercept = glofas_threshold)

subplot(ggplotly(p1), ggplotly(p2), nrows = 2)

all_days %>%
  left_join(glofas_temp) %>%
  left_join(rainfall_temp) %>%
  left_join(df_impact_raw_temp %>% dplyr::select(date) %>% mutate(flood = TRUE)) %>%
  mutate(
    flood = replace_na(flood, FALSE),
    rainfall_exceeds_threshold = rainfall > rainfall_threshold,
    glofas_exceeds_threshold = dis > glofas_threshold,
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