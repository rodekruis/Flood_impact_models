plot_swi <- function(swi, impact_df, threshold){
  p <- swi %>%
    ggplot(aes(x=date, y=swi, color=depth, group=depth)) +
    geom_line() +
    geom_vline(data = impact_df, aes(xintercept = as.numeric(date)), col="red") +
    geom_hline(yintercept = threshold)

  p <- ggplotly(p)

  return(p)
}

plot_rainfall_glofas <- function(rainfall, glofas, impact_df, rainfall_threshold, glofas_threshold, has_glofas){
  if (has_glofas) {
    p1 <- ggplot(rainfall, aes(x=date, y = rainfall)) + geom_line(col='lightblue') +
      ylab("avg. rainfall (mm)") +
      geom_hline(yintercept = rainfall_threshold) +
      geom_vline(data = impact_df, aes(xintercept = as.numeric(date)), col="red") +
      scale_y_continuous(trans = "reverse")

    p2 <- ggplot(glofas, aes(x=date, y = dis)) + geom_line(col='orange') +
      ylab("station discharge") +
      geom_vline(data = impact_df, aes(xintercept = as.numeric(date)), col="red") +
      geom_hline(yintercept = glofas_threshold)

    p3 <- subplot(ggplotly(p1), ggplotly(p2), nrows = 2, titleY=TRUE)
  } else {
    p3 <- ggplot(rainfall, aes(x=date, y = rainfall)) + geom_line(col='lightblue') +
      ylab("avg. rainfall (mm)") +
      geom_hline(yintercept = rainfall_threshold) +
      geom_vline(data = impact_df, aes(xintercept = as.numeric(date)), col="red") +
      scale_y_continuous(trans = "reverse")

    p3 <- ggplotly(p3)
  }

  return(p3)
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