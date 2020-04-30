library(shiny)
library(readr)
library(lubridate)
library(tidyr)
library(plotly)
library(ggplot2)
library(dplyr)

all_data <- read.csv('C:/Users/ATeklesadik/OneDrive - Rode Kruis/Documents/documents/Flood_impact_models/dashboard/catalog_view_kenya/data/Impact_Hazard_catalog.csv',sep=';') %>%
  mutate(date = as_date(Date))


df<-all_data %>% filter(County =='Embu')

plot_impact <- function(df){
  fdata <- df %>% filter(flood !='NA')%>% distinct(County,date,.keep_all = TRUE)
 
  p <-  ggplot() + geom_point(data=fdata, mapping=aes(x=date, y=flood),color = "red",size=3, fill="red")+
    ggtitle('Date with a flood Impact data ')
  
  p <- ggplotly(p)
  return(p)
}


plot_glofas <- function(df){
  fdata <- df %>% filter(flood !='NA')

  p <- df %>% dplyr::select(date, station, contains('dis')) %>%
    rename(t0=dis,t_3days=dis_3day, t_7days=dis_7day) %>% 
    gather('Lead_time','dis',-date,-station) %>%
    ggplot(aes(x=date, y=dis)) +
    geom_line(aes(colour = Lead_time))+ geom_point(data=fdata,aes(x=date, y=100*flood))+
    geom_vline(xintercept = fdata$date, linetype="solid",  color = "red", size=1.5)+
    facet_wrap(~station)

  p <- ggplotly(p)
  return(p)
}


