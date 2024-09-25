from types import SimpleNamespace

base_config = SimpleNamespace(
  incl_level_feats = True,

  # bagging setup
  num_bags = 100,
  bag_frac_samples = 0.7,

  # adjustments to reporting
  reporting_adj = True,

  # data sources and adjustments for reporting issues
  sources = ['flusurvnet', 'ilinet', 'nhsn_state', 'nhsn_city'],

  # fit locations separately or jointly
  fit_locations_separately = False,

  # power transform applied to surveillance signals
  power_transform = '4rt'
)
