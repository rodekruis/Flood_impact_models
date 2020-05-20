predict_with_swi <- function(all_days, swi_raw, df_impact_raw, selected_pcode, threshold=75) {
  all_days %>%
    left_join(swi_raw %>% filter(pcode == selected_pcode, depth == "swi005"), by="date") %>%
    fill(pcode, depth, swi) %>%
    left_join(df_impact_raw %>% filter(pcode == selected_pcode) %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
    mutate(
      flood = replace_na(flood, FALSE),
      swi_exceeds_threshold = swi > threshold,
      flood_correct = flood & swi_exceeds_threshold,
      next_swi_exceeds_threshold = dplyr::lag(swi_exceeds_threshold),
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

predict_with_glofas_and_rainfall <- function(all_days, rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, has_glofas, glofas_variable, day_range=30) {
  rainfall <- rainfall %>%
    filter(!is.na(rainfall))

  if ((nrow(rainfall) > 0) & has_glofas) {
    glofas %>%
      left_join(rainfall, by = "date") %>%
      left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
      mutate(
        row_id = row_number(),
        flood = replace_na(flood, FALSE),
        rainfall = replace_na(rainfall, 0),
        dis = !!sym(glofas_variable),  # name the selected glofas variable discharge
        dis = replace_na(dis, 0),

        # Create peak ranges for combined glofas and rainfall
        rainfall_exceeds_threshold = rainfall >= rainfall_threshold,
        glofas_exceeds_threshold = dis >= glofas_threshold,
        either_exceeds_threshold = rainfall_exceeds_threshold | glofas_exceeds_threshold,
        either_next_exceeds_threshold = lead(either_exceeds_threshold),
        either_prev_exceeds_threshold = dplyr::lag(either_exceeds_threshold),
        either_peak_start = either_exceeds_threshold & !either_prev_exceeds_threshold,
        either_peak_end = either_exceeds_threshold & !either_next_exceeds_threshold,
        either_peak_start_range = lead(either_peak_start, 0),  # There is an option here to also count days before the trigger but currently we don't use it
        either_peak_end_range = dplyr::lag(either_peak_end, day_range),  # Count events day_range amount of days after the trigger as the same peak
        either_peak_end_range = replace_na(either_peak_end_range, FALSE),
        either_in_peak_range = cumsum(either_peak_start_range) > cumsum(either_peak_end_range), # Combine peaks within the same range into a single peak

        # Check when protocol is triggered and whether floods are forecasted correctly
        protocol_triggered = either_in_peak_range & !dplyr::lag(either_in_peak_range),  # Counts number of times protocol is triggered
        flood_correct = flood & either_in_peak_range
      ) %>%
      summarise(
        floods = sum(flood),
        floods_correct = sum(flood_correct),
        floods_incorrect = floods - floods_correct,
        protocol_triggered = sum(protocol_triggered, na.rm=T),
        triggered_in_vain = protocol_triggered - floods_correct,
        detection_ratio = round(floods_correct / floods, 2),
        false_alarm_ratio = round(triggered_in_vain/protocol_triggered, 2)
      )
  } else if (nrow(rainfall) == 0 & has_glofas){
    glofas %>%
      left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
      mutate(
        row_id = row_number(),
        flood = replace_na(flood, FALSE),
        dis = !!sym(glofas_variable),
        dis = replace_na(dis, 0),

        # Create peak ranges for glofas
        glofas_exceeds_threshold = dis >= glofas_threshold,
        glofas_next_exceeds_threshold = lead(glofas_exceeds_threshold),
        glofas_prev_exceeds_threshold = dplyr::lag(glofas_exceeds_threshold),
        glofas_peak_start = glofas_exceeds_threshold & !glofas_prev_exceeds_threshold,
        glofas_peak_end = glofas_exceeds_threshold & !glofas_next_exceeds_threshold,
        glofas_peak_start_range = lead(glofas_peak_start, 0),  # There is an option here to also count days before the trigger but currently we don't use it
        glofas_peak_end_range = dplyr::lag(glofas_peak_end, day_range),  # Draw range around peak
        glofas_peak_end_range = replace_na(glofas_peak_end_range, FALSE),
        glofas_in_peak_range = cumsum(glofas_peak_start_range) > cumsum(glofas_peak_end_range), # Combine peaks within the same range into a single peak

        # Check when protocol is triggered and whether floods are forecasted correctly
        protocol_triggered = glofas_in_peak_range & !dplyr::lag(glofas_in_peak_range),  # Counts number of times protocol is triggered
        flood_correct = flood & glofas_in_peak_range
      ) %>%
      summarise(
        floods = sum(flood),
        floods_correct = sum(flood_correct),
        floods_incorrect = floods - floods_correct,
        protocol_triggered = sum(protocol_triggered, na.rm=T),
        triggered_in_vain = protocol_triggered - floods_correct,
        detection_ratio = round(floods_correct / floods, 2),
        false_alarm_ratio = round(triggered_in_vain/protocol_triggered, 2)
      )
  } else {
    rainfall %>%
      left_join(impact_df %>% dplyr::select(date) %>% mutate(flood = TRUE), by = "date") %>%
      mutate(
        row_id = row_number(),
        flood = replace_na(flood, FALSE),
        rainfall = replace_na(rainfall, 0),

        # Create peak ranges for rainfall
        rainfall_exceeds_threshold = rainfall >= rainfall_threshold,
        rainfall_next_exceeds_threshold = lead(rainfall_exceeds_threshold),
        rainfall_prev_exceeds_threshold = dplyr::lag(rainfall_exceeds_threshold),
        rainfall_peak_start = rainfall_exceeds_threshold & !rainfall_prev_exceeds_threshold,
        rainfall_peak_end = rainfall_exceeds_threshold & !rainfall_next_exceeds_threshold,
        rainfall_peak_start_range = lead(rainfall_peak_start, 0),  # There is an option here to also count days before the trigger but currently we don't use it
        rainfall_peak_end_range = dplyr::lag(rainfall_peak_end, day_range),  # Draw range around peak
        rainfall_peak_end_range = replace_na(rainfall_peak_end_range, FALSE),
        rainfall_in_peak_range = cumsum(rainfall_peak_start_range) > cumsum(rainfall_peak_end_range), # Combine peaks within the same range into a single peak

        # Check when protocol is triggered and whether floods are forecasted correctly
        protocol_triggered = rainfall_in_peak_range & !dplyr::lag(rainfall_in_peak_range),  # Counts number of times protocol is triggered
        flood_correct = flood & rainfall_in_peak_range
      ) %>%
      summarise(
        floods = sum(flood),
        floods_correct = sum(flood_correct),
        floods_incorrect = floods - floods_correct,
        protocol_triggered = sum(protocol_triggered, na.rm=T),
        triggered_in_vain = protocol_triggered - floods_correct,
        detection_ratio = round(floods_correct / floods, 2),
        false_alarm_ratio = round(triggered_in_vain/protocol_triggered, 2)
      )
  }
}
