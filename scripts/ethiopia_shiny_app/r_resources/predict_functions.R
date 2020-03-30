predict_with_threshold <- function(all_days, swi_raw, df_impact_raw, selected_pcode, threshold=75) {
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
