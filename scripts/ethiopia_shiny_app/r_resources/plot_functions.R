plot_swi <- function(swi, impact_df, threshold){
  p <- swi %>%
    ggplot(aes(x=date, y=swi, color=depth, group=depth)) +
    geom_line() + geom_vline(data = impact_df, aes(xintercept = as.numeric(date)), col="red") +
    geom_hline(yintercept = threshold)

  p <- ggplotly(p)

  return(p)
}

prettify_result_table <- function(result_table) {
  result_table %>%
    mutate(
      floods = as.integer(floods),
      floods_correct = as.integer(floods_correct),
      floods_incorrect = as.integer(floods_incorrect),
      protocol_triggered = as.integer(protocol_triggered),
      triggered_in_vain = as.integer(triggered_in_vain),
      triggered_correct = as.integer(triggered_correct)
    ) %>%
    rename(
      `Floods` = floods,
      `Correct Floods` = floods_correct,
      `Incorrect Floods` = floods_incorrect,
      `Protocol Triggered` = protocol_triggered,
      `Triggered in vain` = triggered_in_vain,
      `Triggered Correctly` = triggered_correct,
      `Detection Ratio` = detection_ratio,
      `Fals Alarm Ratio` = false_alarm_ratio
    ) %>%
    gather(var, val)
}