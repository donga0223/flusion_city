library(scoringutils)
library(covidHubUtils)
library(doParallel)
library(ggplot2)
theme_set(theme_bw())

inc_case_targets <- paste(1:4, "wk ahead inc case")

truth_data <- load_truth(
  truth_source = "JHU",
  target_variable = "inc death",
  locations = "US"
)

forecasts_multiple <- load_forecasts(
  models = c("COVIDhub-baseline", "COVIDhub-ensemble"),
  dates = as.Date("2020-12-15") + seq(0, 35, 7),
  # for each date in `dates`, also look at the day before it
  date_window_size = 1,
  locations = "US",
  types = c("point", "quantile"),
  targets = paste(1:4, "wk ahead inc death"),
  source = "zoltar",
  verbose = FALSE,
  as_of = NULL,
  hub = c("US")
)

scores <- score_forecasts(
  forecasts = forecasts_multiple,
  return_format = "wide",
  truth = truth_data
)




c1 <- read.csv("/Users/dk29776/Dropbox/UTAustin/Forecasting/NHSN/data/city_level_data.csv")
statecity_truth <- c1 %>% 
  mutate(state_city = paste(state, city, sep = "_"),
         value = influenza_7_day_sum, 
         target_end_date = collection_week,
         target_variable = "wk inc flu hosp",
         model = "Observed Data (NHSN)") %>%
  mutate(location = gsub(" ", "_", state_city)) %>% 
  select(location, target_end_date, state_city, state, city, value, target_variable, model)
statecity_truth$target_end_date = as.Date(statecity_truth$target_end_date)-1

setwd("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/")
mylocation <- c("NY_NEW_YORK", "CA_LOS_ANGELES", "IL_CHICAGO", "TX_HOUSTON", "AZ_PHOENIX", "PA_PHILADELPHIA", 
                "TX_SAN_ANTONIO", "TX_DALLAS", "TX_AUSTIN", "TX_EL_PASO", "NY_ROCHESTER","NY_ALBANY")
forecast_data <- function(model, ref_date){
  df <- read.csv(paste('output/model_output/', model, '/', ref_date, '-',model, '.csv', sep=""))
  if(model %in% c("gbq_qr", "gbq_qr_nhsn_city_only", "gbq_qr_nhsn_only")){
    df1 <- df %>% mutate(model_id = model) %>%
      filter(horizon < 3, state_city %in% mylocation) %>%
      mutate(horizon = horizon + 1)
  }else{
    df1 <- df %>% mutate(model_id = model) %>%
      filter(horizon < 4, state_city %in% mylocation) 
  }
  
  
  df2 <- df1 %>%
    mutate(location = state_city,
           target_variable = "wk inc flu hosp",
           model = model,
           quantile = output_type_id,
           type = output_type,
           forecast_date = reference_date,
           temporal_resolution = 'wk') %>%
    select(-output_type_id, -output_type, -state_city, -reference_date)
  return(df2)
}

gbq_qr <- forecast_data("gbq_qr", '2023-09-30')
gbq_qr_nhsn_city_only <- forecast_data("gbq_qr_nhsn_city_only", '2023-09-30')
#flusion <- forecast_data("flusion", '2023-10-07')
flusion_frog <- forecast_data("flusion_frog", '2023-10-07')
flusion_hamster <- forecast_data("flusion_hamster", '2023-10-07')

all_forecasts_data <- rbind(gbq_qr, gbq_qr_nhsn_city_only)
all_forecasts_data$target_end_date = as.Date(all_forecasts_data$target_end_date) 


scores <- score_forecasts(
  forecasts = all_forecasts_data,
  return_format = "wide",
  metrics = c("abs_error", "wis", "wis_components", "interval_coverage",
              "quantile_coverage"),
  truth = statecity_truth,
  use_median_as_point=TRUE
)

scores$model <- factor(scores$model, levels = c("gbq_qr", "gbq_qr_nhsn_city_only"))
scores$location <- factor(scores$location, levels = mylocation)


#pdf("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion_city/summary_figures/scores.pdf", width = 15, height = 10)
ggplot(scores, aes(horizon, wis, color = model, group = model)) +
  geom_line()+
  geom_point() +
  facet_wrap(~location)+ 
  theme(panel.spacing=unit(0, "mm"),
        axis.text=element_text(size=15),
        axis.title=element_text(size=20,face="bold"),
        strip.text = element_text(size = 20),
        legend.title = element_text(size = 18),
        legend.text = element_text(size = 15))

ggplot(scores, aes(horizon, abs_error, color = model, group = model)) +
  geom_line()+
  geom_point() +
  facet_wrap(~location)+ 
  theme(panel.spacing=unit(0, "mm"),
        axis.text=element_text(size=15),
        axis.title=element_text(size=20,face="bold"),
        strip.text = element_text(size = 20),
        legend.title = element_text(size = 18),
        legend.text = element_text(size = 15))
dev.off()



scores %>% 
  filter(horizon==1) %>%
  select(location,model, abs_error) %>% 
  cast(location ~ model)

gsub(" " , "&", "16.0144875      17.6938323 10.5741705 12.2061401    16.777229      10.2482474")
