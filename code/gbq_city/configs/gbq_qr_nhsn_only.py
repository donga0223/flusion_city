import copy
from configs.base import base_config

config = copy.deepcopy(base_config)
config.model_name = 'gbq_qr_nhsn_only'

config.bag_frac_samples = 1
config.sources = ['nhsn_city', 'nhsn_state']
