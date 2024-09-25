
library(hubEnsembles)
setwd("/Users/dk29776/Dropbox/UTAustin/Forecasting/flusion/")

filterdata <- function(model, ref_date){
  df <- read.csv(paste('model-output/', model, '-statecity/', ref_date, '-',model, '.csv', sep=""))
  df1 <- df %>% mutate(model_id = model) %>%
    filter(horizon < 3) %>%
    mutate(horizon = horizon + 1)
  return(df1)
}


flusion_model <- function(ref_date){
  gbq_qr <- filterdata("gbq_qr", ref_date)
  gbq_qr_no_level <- filterdata("gbq_qr_no_level", ref_date)
  sarix <- filterdata("sarix", ref_date)
  
  forecasts <- rbind(gbq_qr, gbq_qr_no_level, sarix)
  
  #################################
  # generate median ensemble
  #################################
  
  ensemble_outputs <- hubEnsembles::simple_ensemble(
    forecasts,
    # agg_fun="median",
    agg_fun="mean",
    task_id_cols=c("reference_date", "state_city", "horizon", "target", "target_end_date"),
  ) |>
    dplyr::select(-model_id)
  
  
  if (!dir.exists("model-output/flusion-statecity/")) {
    dir.create("model-output/flusion-statecity/")
  }
  readr::write_csv(
    ensemble_outputs,
    paste0("model-output/flusion-statecity/", ref_date, "-flusion.csv"))
  
  
  ##################################################################
  # hamster method: weight 0.25 to gb methods, 0.5 to sarix
  ##################################################################
  ensemble_outputs <- hubEnsembles::simple_ensemble(
    forecasts,
    # agg_fun="median",
    agg_fun="mean",
    task_id_cols=c("reference_date", "state_city", "horizon", "target", "target_end_date"),
    weights = data.frame(
      model_id = c("gbq_qr", "gbq_qr_no_level", "sarix"),
      weight = c(0.25, 0.25, 0.5)
    )
  ) |>
    dplyr::select(-model_id)
  
  
  if (!dir.exists("model-output/flusion_hamster-statecity/")) {
    dir.create("model-output/flusion_hamster-statecity/")
  }
  readr::write_csv(
    ensemble_outputs,
    paste0("model-output/flusion_hamster-statecity/", ref_date, "-flusion_hamster.csv"))
  
  #################################
  # frog method: only gb components
  #################################
  ensemble_outputs <- hubEnsembles::simple_ensemble(
    forecasts,
    # agg_fun="median",
    agg_fun="mean",
    task_id_cols=c("reference_date", "state_city", "horizon", "target", "target_end_date"),
    weights = data.frame(
      model_id = c("gbq_qr", "gbq_qr_no_level", "sarix"),
      weight = c(0.5, 0.5, 0.0)
    )
  ) |>
    dplyr::select(-model_id)
  
  
  if (!dir.exists("model-output/flusion_frog-statecity/")) {
    dir.create("model-output/flusion_frog-statecity/")
  }
  readr::write_csv(
    ensemble_outputs,
    paste0("model-output/flusion_frog-statecity/", ref_date, "-flusion_frog.csv"))
}


flusion_model("2023-10-07")
flusion_model("2023-11-25")
flusion_model("2024-01-13")
flusion_model("2024-02-24")
flusion_model("2024-03-30")



