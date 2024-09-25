
library(tidyverse)
setwd("/Users/dk29776/Dropbox/UTAustin/Forecasting")

c1 <- read.csv("NHSN/data/city_level_data.csv")


out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-10-07-gbq_qr.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-11-25-gbq_qr.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-01-13-gbq_qr.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-02-24-gbq_qr.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-03-30-gbq_qr.csv')

out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr/2023-09-30-gbq_qr.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr/2023-11-18-gbq_qr.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr/2024-01-06-gbq_qr.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr/2024-02-17-gbq_qr.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr/2024-03-23-gbq_qr.csv')


out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr_nhsn_city_only/2023-09-30-gbq_qr_nhsn_city_only.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr_nhsn_city_only/2023-11-18-gbq_qr_nhsn_city_only.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr_nhsn_city_only/2024-01-06-gbq_qr_nhsn_city_only.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr_nhsn_city_only/2024-02-17-gbq_qr_nhsn_city_only.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/output/model_output/gbq_qr_nhsn_city_only/2024-03-23-gbq_qr_nhsn_city_only.csv')


forecast_est_data <- function(out, i){
  out <- out %>% mutate(no = as.factor(i))
  ribbon_data <- out %>%
    filter(output_type_id %in% c(0.025, 0.5, 0.975)) %>%
    spread(output_type_id, value) %>%
    rename(est_low = `0.025`, est_high = `0.975`, est_median = `0.5`)
  
  ribbon_data$target_end_date = as.Date(ribbon_data$target_end_date)+1
  return(ribbon_data)
}

ribbon_data <- forecast_est_data(out1, 1)
ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))

my_state_city = c('NY_NEW_YORK', 'CA_LOS_ANGELES', 'IL_CHICAGO', 'TX_HOUSTON', 
                  'AZ_PHOENIX', 'PA_PHILADELPHIA', 'NY_ROCHESTER', 'NY_ALBANY',
                  'TX_DALLAS', 'TX_SAN_ANTONIO', 'TX_AUSTIN', 'TX_EL_PASO')

df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
              city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 
                          'PHILADELPHIA', 'ALBANY', 'ROCHESTER',
                          'DALLAS', 'SAN ANTONIO', 'AUSTIN', 'EL PASO')) %>% 
  mutate(state_city = paste(state, city, sep = "_")) %>%
  select(collection_week, state_city, state, city, influenza_7_day_sum) 

df$state_city <- gsub(" ", "_", df$state_city)
df$collection_week <- as.Date(df$collection_week)

df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
df %>% filter(collection_week == '2024-01-14')
df$state_city <- factor(df$state_city, levels = my_state_city)


#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/summary_figures/forecast_figures_gbq_qr.pdf", width = 15, height = 10)
df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
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
  
dev.off()



########################################################################################################
#### Using NHSN data (state and city)
########################################################################################################

rm(ribbon_data)
rm(df)
out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-10-07-gbq_qr-nhsn.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-11-25-gbq_qr-nhsn.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-01-13-gbq_qr-nhsn.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-02-24-gbq_qr-nhsn.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-03-30-gbq_qr-nhsn.csv')


ribbon_data <- forecast_est_data(out1, 1)
ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))

df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
                    city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 'PHILADELPHIA', 'ALBANY', 'ROCHESTER')) %>% 
  mutate(state_city = paste(state, city, sep = "_")) %>%
  select(collection_week, state_city, state, city, influenza_7_day_sum) 

df$state_city <- gsub(" ", "_", df$state_city)
df$collection_week <- as.Date(df$collection_week)

df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
df %>% filter(collection_week == '2024-01-14')
df$state_city <- factor(df$state_city, levels = my_state_city)

#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/res_gbq_qr-citystate-nhsn.pdf", width = 15, height = 10)
df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
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
dev.off()



########################################################################################################
#### Using NHSN data (city only)
########################################################################################################



rm(ribbon_data)
rm(df)
out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-10-07-gbq_qr-nhsn-cityonly.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-11-25-gbq_qr-nhsn-cityonly.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-01-13-gbq_qr-nhsn-cityonly.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-02-24-gbq_qr-nhsn-cityonly.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-03-30-gbq_qr-nhsn-cityonly.csv')


ribbon_data <- forecast_est_data(out1, 1)
ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))

df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
                    city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 'PHILADELPHIA', 'ALBANY', 'ROCHESTER')) %>% 
  mutate(state_city = paste(state, city, sep = "_")) %>%
  select(collection_week, state_city, state, city, influenza_7_day_sum) 

df$state_city <- gsub(" ", "_", df$state_city)
df$collection_week <- as.Date(df$collection_week)

df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
df %>% filter(collection_week == '2024-01-14')
df$state_city <- factor(df$state_city, levels = my_state_city)

#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/res_gbq_qr-citystate-nhsn-cityonly.pdf", width = 15, height = 10)
df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
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
dev.off()




########################################################################################################
#### Using all data and all flusurvnet and all NHSN state level data 
########################################################################################################



rm(ribbon_data)
rm(df)
out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-10-07-gbq_qr-allflusurvnet.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2023-11-25-gbq_qr-allflusurvnet.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-01-13-gbq_qr-allflusurvnet.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-02-24-gbq_qr-allflusurvnet.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr-citystate/2024-03-30-gbq_qr-allflusurvnet.csv')


ribbon_data <- forecast_est_data(out1, 1)
ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))

my_state_city = c('NY_NEW_YORK', 'CA_LOS_ANGELES', 'IL_CHICAGO', 'TX_HOUSTON', 
                  'AZ_PHOENIX', 'PA_PHILADELPHIA', 'NY_ROCHESTER', 'NY_ALBANY',
                  'TX_SAN_ANTONIO', 'TX_DALLAS' ,'TX_AUSTIN', 'TX_EL_PASO')


df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
                    city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 
                                'PHILADELPHIA', 'ALBANY', 'ROCHESTER', 'SAN ANTONIO', 
                                'DALLAS' ,'AUSTIN', 'EL PASO')) %>% 
  mutate(state_city = paste(state, city, sep = "_")) %>%
  select(collection_week, state_city, state, city, influenza_7_day_sum) 

df$state_city <- gsub(" ", "_", df$state_city)
df$collection_week <- as.Date(df$collection_week)

df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
df %>% filter(collection_week == '2024-01-14')
df$state_city <- factor(df$state_city, levels = my_state_city)

#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/res_gbq_qr-citystate-nhsn-allflusurvnet.pdf", width = 15, height = 10)
df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
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
dev.off()



########################################################################################################
#### Using all data and all flusurvnet and all NHSN state level data  (no level)
########################################################################################################



rm(ribbon_data)
rm(df)
out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr_no_level-statecity/2023-10-07-gbq_qr_no_level.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr_no_level-statecity/2023-11-25-gbq_qr_no_level.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr_no_level-statecity/2024-01-13-gbq_qr_no_level.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr_no_level-statecity/2024-02-24-gbq_qr_no_level.csv')
#out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr_no_level-statecity/2024-01-20-gbq_qr_no_level.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/gbq_qr_no_level-statecity/2024-03-30-gbq_qr_no_level.csv')


ribbon_data <- forecast_est_data(out1, 1)
ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))

my_state_city = c('NY_NEW_YORK', 'CA_LOS_ANGELES', 'IL_CHICAGO', 'TX_HOUSTON', 
                  'AZ_PHOENIX', 'PA_PHILADELPHIA', 'NY_ROCHESTER', 'NY_ALBANY',
                  'TX_SAN_ANTONIO', 'TX_DALLAS' ,'TX_AUSTIN', 'TX_EL_PASO')


df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
                    city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 
                                'PHILADELPHIA', 'ALBANY', 'ROCHESTER', 'SAN ANTONIO', 
                                'DALLAS' ,'AUSTIN', 'EL PASO')) %>% 
  mutate(state_city = paste(state, city, sep = "_")) %>%
  select(collection_week, state_city, state, city, influenza_7_day_sum) 

df$state_city <- gsub(" ", "_", df$state_city)
df$collection_week <- as.Date(df$collection_week)

df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
df %>% filter(collection_week == '2024-01-14')
df$state_city <- factor(df$state_city, levels = my_state_city)

#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/res_gbq_qr-nolevel.pdf", width = 15, height = 10)
df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
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
dev.off()





########################################################################################################
#### SARIX (nhsn_city only but all city)
########################################################################################################



rm(ribbon_data)
rm(df)
out1 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/sarix-statecity/2023-10-07-sarix.csv')
out2 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/sarix-statecity/2023-11-25-sarix.csv')
out3 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/sarix-statecity/2024-01-13-sarix.csv')
out4 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/sarix-statecity/2024-02-24-sarix.csv')
out5 <- read.csv('/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/sarix-statecity/2024-03-30-sarix.csv')

ribbon_data <- forecast_est_data(out1, 1)
ribbon_data <- rbind(ribbon_data, forecast_est_data(out2, 2))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out3, 3))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out4, 4))
ribbon_data <- rbind(ribbon_data, forecast_est_data(out5, 5))

my_state_city = c('NY_NEW_YORK', 'CA_LOS_ANGELES', 'IL_CHICAGO', 'TX_HOUSTON', 
                  'AZ_PHOENIX', 'PA_PHILADELPHIA', 'NY_ROCHESTER', 'NY_ALBANY',
                  'TX_SAN_ANTONIO', 'TX_DALLAS' ,'TX_AUSTIN', 'TX_EL_PASO')


df <- c1 %>% filter(state %in% c('NY', 'CA', 'IL', 'TX', 'AZ', 'PA'),
                    city %in% c('NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON', 'PHOENIX', 
                                'PHILADELPHIA', 'ALBANY', 'ROCHESTER', 'SAN ANTONIO', 
                                'DALLAS' ,'AUSTIN', 'EL PASO')) %>% 
  mutate(state_city = paste(state, city, sep = "_")) %>%
  select(collection_week, state_city, state, city, influenza_7_day_sum) 

df$state_city <- gsub(" ", "_", df$state_city)
df$collection_week <- as.Date(df$collection_week)

df <- df %>% left_join(ribbon_data, by = c('state_city', "collection_week" = "target_end_date"))
df %>% filter(collection_week == '2024-01-14')
df$state_city <- factor(df$state_city, levels = my_state_city)

#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/model-output/res_sarix-citystate.pdf", width = 15, height = 10)
df %>% filter(collection_week >= as.Date('2023-08-01')) %>%
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
dev.off()





