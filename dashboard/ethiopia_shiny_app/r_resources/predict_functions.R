predict_with_swi <- function(all_days, swi_raw, df_impact_raw, selected_pcode, threshold=75) {
  all_days %>%
    left_join(swi_raw %>% filter(pcode == selected_pcode, depth == "swi005"), by="date") %>%
    fill(pcode, depth, swi) %>%
    left_join(df_impact_raw %>% filter(pcode == selected_pcode) %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
    mutate(
      flood = replace_na(flood, FALSE),
      swi_exceeds_threshold = swi > threshold,
      flood_correct = flood & swi_exceeds_threshold,
      next_swi_exceeds_threshold = lag(swi_exceeds_threshold),
      peak_start = !swi_exceeds_threshold & next_swi_exceeds_threshold
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
}

predict_with_glofas_and_rainfall <- function(all_days, rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, has_glofas) {
  if (has_glofas) {
    all_days %>%
      left_join(glofas) %>%
      left_join(rainfall) %>%
      left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE)) %>%
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
  } else {
    all_days %>%
      left_join(rainfall) %>%
      left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE)) %>%
      mutate(
        flood = replace_na(flood, FALSE),
        rainfall_exceeds_threshold = rainfall > rainfall_threshold,
        flood_correct = flood & rainfall_exceeds_threshold,
        next_exceeds_threshold = lag(rainfall_exceeds_threshold),
        peak_start = !rainfall_exceeds_threshold & next_exceeds_threshold
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
  }
}