plot_rainfall_shifts <- function(df){
  p <- df %>%
    dplyr::select(date, contains('shift')) %>%
    gather("var", "val", -date) %>%
    ggplot(aes(x=date, y=val)) + geom_line() + facet_wrap(~var)

  p <- ggplotly(p)
  return(p)
}

plot_rainfall_cums <- function(df){
  p <- df %>%
    dplyr::select(date, contains('days'), contains('anomaly')) %>%
    gather("var", "val", -date) %>%
    ggplot(aes(x=date, y=val)) + geom_line() + facet_wrap(~var)

  p <- ggplotly(p)
  return(p)
}

plot_glofas <- function(df){
  p <- df %>%
    dplyr::select_if(~sum(!is.na(.)) > 0) %>%
    dplyr::select(date, contains('F0'), contains('G61'), contains('G52'), contains('G51')) %>%
    drop_na() %>%
    gather("var", "val", -date) %>%
    ggplot(aes(x=date, y=val)) + geom_line() + facet_wrap(~var)

  p <- ggplotly(p)
  return(p)
}
