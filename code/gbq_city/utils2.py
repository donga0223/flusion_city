from types import SimpleNamespace
import importlib
import datetime

def create_configs(ref_date, model_name, output_root, artifact_store_root, save_feat_importance, short_run):
    '''
    Create configuration objects for the model and the run.

    Parameters
    ----------
    ref_date : str
        The reference date for the forecast.
    model_name : str
        The name of the model configuration to import.
    output_root : str
        The root directory for saving model outputs.
    artifact_store_root : str
        The path to the artifact store.
    save_feat_importance : bool
        Flag to indicate whether to save feature importance.
    short_run : bool
        Flag to indicate if a short run configuration is required.

    Returns
    -------
    model_config : object
        Configuration settings for the model.
    run_config : SimpleNamespace
        Configuration settings for the run.
    '''

    ref_date = _validate_ref_date(ref_date)
    
    model_config = importlib.import_module(f'configs.{model_name}').config
    
    run_config = SimpleNamespace(
        ref_date=ref_date,
        output_root=output_root,
        artifact_store_root=artifact_store_root,
        save_feat_importance=save_feat_importance
    )
    
    if short_run:
        # override model-specified num_bags to a smaller value
        model_config.num_bags = 10
        
        # maximum forecast horizon
        run_config.max_horizon = 3
        
        # quantile levels at which to generate predictions
        run_config.q_levels = [0.025, 0.50, 0.975]
        run_config.q_labels = ['0.025', '0.5', '0.975']
    else:
        # maximum forecast horizon
        run_config.max_horizon = 5
        
        # quantile levels at which to generate predictions
        run_config.q_levels = [0.01, 0.025, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30,
                               0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70,
                               0.75, 0.80, 0.85, 0.90, 0.95, 0.975, 0.99]
        run_config.q_labels = ['0.01', '0.025', '0.05', '0.1', '0.15', '0.2',
                               '0.25', '0.3', '0.35', '0.4', '0.45', '0.5',
                               '0.55', '0.6', '0.65', '0.7', '0.75', '0.8',
                               '0.85', '0.9', '0.95', '0.975', '0.99']
    
    return model_config, run_config


def _validate_ref_date(ref_date):
    if ref_date is None:
        today = datetime.date.today()
        
        # next Saturday: weekly forecasts are relative to this date
        ref_date = today - datetime.timedelta((today.weekday() + 2) % 7 - 7)
        
        return ref_date
    elif isinstance(ref_date, datetime.date):
        # check that it's a Saturday
        if ref_date.weekday() != 5:
            raise ValueError('ref_date must be a Saturday')
        
        return ref_date
    else:
        raise TypeError('ref_date must be a datetime.date object')
