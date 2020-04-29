
plot_impact <- function(df){
  fdata <- df %>% filter(flood !='NA')%>% distinct(Zone,date,.keep_all = TRUE)
 
  p <-  ggplot() + geom_point(data=fdata, mapping=aes(x=date, y=flood),color = "red",size=3, fill="red")+
    ggtitle('Date with a flood Impact data ')
  
  p <- ggplotly(p)
  return(p)
}

plot_rainfall <- function(df){
  fdata <- df %>% filter(flood !='NA')
     p <- df %>%
    dplyr::select(date, Rainfall,rain_station,flood) %>%
    ggplot(aes(x=date, y=Rainfall)) + 
       geom_line() +geom_point(data=fdata,aes(x=date, y=10*flood))+
       geom_vline(xintercept = fdata$date, linetype="solid",  color = "red", size=1.5)+
      facet_wrap(~rain_station)
     

  p <- ggplotly(p)
  return(p)
}

plot_rainfall_cums <- function(df){
  fdata <- df %>% filter(flood !='NA')

  p <- df %>% dplyr::select(date, Rainfall,rain_station,flood) %>% mutate(rain_t2= rollapplyr(Rainfall, width = 2, FUN = sum, partial = TRUE),
           rain_t3 = rollapplyr(Rainfall, width = 3, FUN = sum, partial = TRUE),
           rain_t5 = rollapplyr(Rainfall, width = 5, FUN = sum, partial = TRUE))%>%
    rename(rain_t0=Rainfall)%>% gather("cum_days","Rainfall",-rain_station,-date,-flood )%>%
    ggplot(aes(x=date, y=Rainfall)) +  
    geom_line(aes(colour = cum_days)) +geom_point(data=fdata,aes(x=date, y=50*flood))+
    geom_vline(xintercept = fdata$date, linetype="solid",  color = "red", size=1.5)+
    facet_wrap(~rain_station)

  p <- ggplotly(p)
  return(p)
}

plot_glofas <- function(df){
  fdata <- df %>% filter(flood !='NA')

  p <- df %>%
    #dplyr::select_if(~sum(!is.na(.)) > 0) %>%
    dplyr::select(date, station, contains('dis')) %>% rename(t0=dis,t_3days=dis_3day, t_7days=dis_7day) %>% 
    drop_na() %>%
    gather('Lead_time','dis',-date,-station) %>%
    ggplot(aes(x=date, y=dis)) +
    geom_line(aes(colour = Lead_time))+ geom_point(data=fdata,aes(x=date, y=100*flood))+
    geom_vline(xintercept = fdata$date, linetype="solid",  color = "red", size=1.5)+
    facet_wrap(~station)

  p <- ggplotly(p)
  return(p)
}


