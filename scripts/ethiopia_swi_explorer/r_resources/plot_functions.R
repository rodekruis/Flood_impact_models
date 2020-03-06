plot_swi <- function(swi, impact_df){
  p <- swi %>%
    ggplot(aes(x=date, y=swi, color=depth, group=depth)) +
    geom_line() + geom_vline(data = impact_df, aes(xintercept = as.numeric(date)), col="red")

  p <- ggplotly(p)

  return(p)
}