
library(tidyverse)
setwd("/Users/dk29776/Dropbox/UTAustin/Forecasting")

c1 <- read.csv("NHSN/data/city_level_data.csv")

forecast_est_data <- function(out, i){
  out <- out %>% mutate(no = as.factor(i))
  ribbon_data <- out %>%
    filter(output_type_id %in% c(0.025, 0.5, 0.975)) %>%
    spread(output_type_id, value) %>%
    rename(est_low = `0.025`, est_high = `0.975`, est_median = `0.5`)
  
  ribbon_data$target_end_date = as.Date(ribbon_data$target_end_date)+1
  return(ribbon_data)
}


summary_plot <- function(model, pdf=FALSE){
  out1 <- read.csv(paste('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/', model, '-statecity/2023-10-07-', model, '.csv', sep = ""))
  out2 <- read.csv(paste('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/', model, '-statecity/2023-11-25-', model, '.csv', sep = ""))
  out3 <- read.csv(paste('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/', model, '-statecity/2024-01-13-', model, '.csv', sep = ""))
  out4 <- read.csv(paste('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/', model, '-statecity/2024-02-24-', model, '.csv', sep = ""))
  out5 <- read.csv(paste('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/', model, '-statecity/2024-03-30-', model, '.csv', sep = ""))
  
  ribbon_data <- forecast_est_data(out1, 1)
  ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
  ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
  ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
  ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))
  
  my_state_city = c('NY_NEW_YORK', 'CA_LOS_ANGELES', 'IL_CHICAGO', 'TX_HOUSTON', 
                    'AZ_PHOENIX', 'PA_PHILADELPHIA', 'TX_SAN_ANTONIO', 'TX_DALLAS',
                    'TX_AUSTIN', 'TX_EL_PASO', 'NY_ROCHESTER', 'NY_ALBANY')
  
  df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
                      city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 'PHILADELPHIA', 'SAN ANTONIO', 'DALLAS', 'AUSTIN', 'EL PASO', 'ALBANY', 'ROCHESTER')) %>% 
    mutate(state_city = paste(state, city, sep = "_")) %>%
    select(collection_week, state_city, state, city, influenza_7_day_sum) 
  
  df$state_city <- gsub(" ", "_", df$state_city)
  df$collection_week <- as.Date(df$collection_week)
  
  df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
  df %>% filter(collection_week == '2024-01-14')
  df$state_city <- factor(df$state_city, levels = my_state_city)
  
  p <- df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
    ggplot(aes(collection_week, influenza_7_day_sum)) +
    geom_ribbon(aes(ymin = est_low, ymax = est_high), alpha = 0.2, col = 'gray') + # Add shaded ribbon
    geom_point(col="gray30", size=0.95, shape=1, alpha=0.9) +
    geom_line(col="gray30", alpha=0.9) +
    geom_line(aes(y = est_median, col = no, group = no), size = 1) +
    geom_point(aes(y = est_median, col = no, group = no, alpha = 0.9), size = 1.5) +
    facet_wrap(~state_city, scales = "free_y") + 
    theme(panel.spacing=unit(0, "mm"),
          legend.position = "none",
          axis.text.y=element_text(size=15),
          axis.text.x=element_text(size=10),
          axis.title=element_text(size=20,face="bold"),
          strip.text = element_text(size = 20))
  print(p)
  
  if(pdf){
    pdf(paste('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/res_figures/', model, '-statecity.pdf', sep = ""), width = 15, height = 10)
    print(p)
    dev.off()
  }  
  
}

summary_plot(model = "gbq_qr", pdf = TRUE)
summary_plot(model = "gbq_qr_no_level", pdf = TRUE)
summary_plot(model = "sarix", pdf = TRUE)
summary_plot(model = "flusion", pdf = TRUE)
summary_plot(model = "flusion_frog", pdf = TRUE)
summary_plot(model = "flusion_hamster", pdf = TRUE)
