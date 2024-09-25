import argparse
import pathlib
import numpy as np
import pandas as pd

import datetime
import time

from matplotlib import cm
import matplotlib.pyplot as plt
import seaborn as sns

import lightgbm as lgb

# https://github.com/reichlab/timeseriesutils
from timeseriesutils import featurize

import datetime


import utils2
import run


# c("2023-10-01", "2023-11-19", "2024-01-07", "2024-02-18", "2024-03-24")


def run_model(ref_date, model_name, short_run):

    model_config, run_config = utils2.create_configs(
        ref_date=ref_date,
        model_name=model_name,
        output_root='output/model_output',
        artifact_store_root='output/model-artifacts',
        save_feat_importance=True,
        short_run=short_run
    )


    target_statecity = ['NY_NEW_YORK', 'CA_LOS_ANGELES', 
                        'IL_CHICAGO', 'TX_HOUSTON', 'AZ_PHOENIX',
                        'PA_PHILADELPHIA', 'NY_ROCHESTER', 'NY_ALBANY',
                        'TX_SAN_ANTONIO', 'TX_DALLAS', 'TX_AUSTIN',
                        'TX_EL_PASO']

    run.run_gbq_flu_model(model_config, run_config, target_statecity)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Run gradient boosting model for flu prediction')
    parser.add_argument('--ref_date',
                        help='reference date for predictions in format YYYY-MM-DD; a Saturday',
                        type=lambda s: datetime.date.fromisoformat(s),
                        default='2023-09-30')
    parser.add_argument('--model_name',
                        help='Model name',
                        choices=['gbq_qr', 'gbq_qr_nhsn_only', 'gbq_qr_nhsn_city_only'],
                        default='gbq_qr')
    parser.add_argument('--short_run',
                        action=argparse.BooleanOptionalAction,
			help='Flag to do a short run; overrides model-default num_bags to 10 and uses 3 quantile levels')
    parser.set_defaults(short_run=False)
    args = parser.parse_args()
    
    run_model(**vars(args))