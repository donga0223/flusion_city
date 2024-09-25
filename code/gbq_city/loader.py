from pathlib import Path
import glob

from itertools import product

import numpy as np
import pandas as pd

import pymmwr

import datetime
from pandas.tseries.holiday import USFederalHolidayCalendar


def date_to_ew_str(row, date_col_name='wk_end_date'):
    ew = pymmwr.date_to_epiweek(datetime.date.fromisoformat(row[date_col_name]))
    # ew_str = pd.Series(str(ew.year) + str(ew.week))
    ew_str = str(ew.year) + str(ew.week)
    return ew_str


# convert epi week to season week
def convert_epiweek_to_season_week(epiweek):
  """Convert season and epiweek to season and season week.
  Args:
      epiweek in format 'yyyyww'
  Return:
      season_week: integer between 1 and 52
  """
  epiweek_year = epiweek.str[:4].astype(int)
  epiweek_week = epiweek.str[4:].astype(int)
  
  season_week = epiweek_week - 30

  update_inds = (season_week <= 0)
  season_week[update_inds] = season_week[update_inds] + \
    [pymmwr.epiweeks_in_year(int(epiweek_year[update_inds].values[i]) - 1) for i in range(np.sum(update_inds))]
  
  return season_week


def convert_epiweek_to_season(epiweek):
  """Convert season and epiweek to season and season week.
  Args:
      epiweek in format 'yyyyww'
  Return:
      season: string in format '2018/19'
  """
  epiweek_year = epiweek.str[:4].astype(int)
  epiweek_week = epiweek.str[4:].astype(int)
  
  update_inds = (epiweek_week <= 30)
  epiweek_year = epiweek_year - update_inds
  season = epiweek_year.astype(str)
  season = season + '/' + (season.str[-2:].astype(int) + 1).astype(str)
  
  return season


def convert_datetime_to_season_week(row, date_col_name):
  ew = pymmwr.date_to_epiweek(row[date_col_name].date())
  ew_str = pd.Series(str(ew.year) + str(ew.week))
  return convert_epiweek_to_season_week(ew_str)


def get_season_hol(start_year):
  holiday_cal = USFederalHolidayCalendar()
  hol = holiday_cal.holidays(
    start=datetime.datetime(year=start_year, month=7, day=1),
    end=datetime.datetime(year=start_year+1, month=6, day=1),
    return_name=True)
    
  hol = hol.reset_index()
  hol.columns = ['date', 'holiday']
  hol = hol.loc[hol['holiday'].isin(['Thanksgiving Day', 'Christmas Day'])]
  
  hol['season'] = str(start_year) + '/' + str(start_year + 1)[-2:]
  
  return hol


def get_holidays():
  hol = pd.concat([get_season_hol(sy) for sy in range(1997, 2024)],
                  ignore_index=True)
  hol['season_week'] = hol.apply(convert_datetime_to_season_week, axis=1, date_col_name='date')
  
  return hol[['season', 'holiday', 'date', 'season_week']]



def load_fips_mappings():
  return pd.read_csv('data-raw/fips-mappings/fips_mappings.csv')


def load_flusurv_rates_2022_23():
  dat = pd.read_csv('data-raw/influenza-flusurv/flusurv-rates/flusurv-rates-2022-23.csv',
                    encoding='ISO-8859-1',
                    engine='python')
  dat.columns = dat.columns.str.lower()
  
  dat = dat.loc[(dat['age category'] == 'Overall') &
                (dat['sex category'] == 'Overall') &
                (dat['race category'] == 'Overall')]
  
  dat = dat.loc[~((dat.catchment == 'Entire Network') &
                  (dat.network != "FluSurv-NET"))]

  dat['location'] = dat['catchment']
  dat['agg_level'] = np.where(dat['location'] == 'Entire Network', 'national', 'site')
  dat['season'] = dat['year'].str.replace('-', '/')
  epiweek = dat['mmwr-year'].astype(str) + dat['mmwr-week'].astype(str)
  dat['season_week'] = convert_epiweek_to_season_week(epiweek)
  dat['wk_end_date'] = dat.apply(
    lambda x: pymmwr.epiweek_to_date(pymmwr.Epiweek(year=x['mmwr-year'],
                                                    week=x['mmwr-week'],
                                                    day=7))
                                    .strftime("%Y-%m-%d"),
      axis=1)
  dat['wk_end_date'] = pd.to_datetime(dat['wk_end_date'])
  dat['inc'] = dat['weekly rate ']
  dat = dat[['agg_level', 'location', 'season', 'season_week', 'wk_end_date', 'inc']]
  
  return dat


def load_flusurv_rates_base( 
                            seasons=None,
                            locations=['California', 'Colorado', 'Connecticut', 'Entire Network',
                                      'Georgia', 'Maryland', 'Michigan', 'Minnesota', 'New Mexico',
                                      'New York - Albany', 'New York - Rochester', 'Ohio', 'Oregon',
                                      'Tennessee', 'Utah'],
                            age_labels=['0-4 yr', '5-17 yr', '18-49 yr', '50-64 yr', '65+ yr', 'Overall']
                            ):
  # read flusurv data and do some minimal preprocessing
  dat = pd.read_csv('data-raw/influenza-flusurv/flusurv-rates/old-flusurv-rates.csv',
                    encoding='ISO-8859-1',
                    engine='python')
  dat.columns = dat.columns.str.lower()
  dat['season'] = dat.sea_label.str.replace('-', '/')
  dat['inc'] = dat.weeklyrate
  dat['location'] = dat['region']
  dat['agg_level'] = np.where(dat['location'] == 'Entire Network', 'national', 'site')
  dat = dat[dat.age_label.isin(age_labels)]
  
  dat = dat.sort_values(by=['wk_end'])
  
  dat['wk_end_date'] = pd.to_datetime(dat['wk_end'])
  dat = dat[['agg_level', 'location', 'season', 'season_week', 'wk_end_date', 'inc']]
  
  # add in data from 2022/23 season
  dat = pd.concat(
    [dat, load_flusurv_rates_2022_23()],
    axis = 0
  )
  
  dat = dat[dat.location.isin(locations)]
  if seasons is not None:
    dat = dat[dat.season.isin(seasons)]
  
  dat['source'] = 'flusurvnet'
  
  return dat


def load_one_us_census_file( f):
  dat = pd.read_csv(f, engine='python', dtype={'STATE': str})
  dat = dat.loc[(dat['NAME'] == 'United States') | (dat['STATE'] != '00'),
                (dat.columns == 'STATE') | (dat.columns.str.startswith('POPESTIMATE'))]
  dat = dat.melt(id_vars = 'STATE', var_name='season', value_name='pop')
  dat.rename(columns={'STATE': 'location'}, inplace=True)
  dat.loc[dat['location'] == '00', 'location'] = 'US'
  dat['season'] = dat['season'].str[-4:]
  dat['season'] = dat['season'] + '/' + (dat['season'].str[-2:].astype(int) + 1).astype(str)
  
  return dat


def load_us_census( fillna = True):
  files = [
    'data-raw/us-census/nst-est2019-alldata.csv',
    'data-raw/us-census/NST-EST2022-ALLDATA.csv']
  us_pops = pd.concat([load_one_us_census_file(f) for f in files], axis=0)
  
  fips_mappings = pd.read_csv('data-raw/fips-mappings/fips_mappings.csv')
  
  hhs_pops = us_pops.query("location != 'US'") \
    .merge(
        fips_mappings.query("location != 'US'") \
            .assign(hhs_region=lambda x: 'Region ' + x['hhs_region'].astype(int).astype(str)),
        on='location',
        how = 'left'
    ) \
    .groupby(['hhs_region', 'season']) \
    ['pop'] \
    .sum() \
    .reset_index() \
    .rename(columns={'hhs_region': 'location'})
  
  dat = pd.concat([us_pops, hhs_pops], axis=0)
  
  if fillna:
    all_locations = dat['location'].unique()
    all_seasons = [str(y) + '/' + str(y+1)[-2:] for y in range(1997, 2024)]
    full_result = pd.DataFrame.from_records(product(all_locations, all_seasons))
    full_result.columns = ['location', 'season']
    dat = full_result.merge(dat, how='left', on=['location', 'season']) \
      .set_index('location') \
      .groupby(['location']) \
      .bfill() \
      .groupby(['location']) \
      .ffill() \
      .reset_index()
  
  return dat


def load_hosp_burden():
  burden_estimates = pd.read_csv(
    'data-raw/burden-estimates/burden-estimates.csv',
    engine='python')

  burden_estimates.columns = ['season', 'hosp_burden']

  burden_estimates['season'] = burden_estimates['season'].str[:4] + '/' + burden_estimates['season'].str[7:9]

  return burden_estimates


def calc_hosp_burden_adj():
  dat = load_flusurv_rates_base(
    seasons = ['20' + str(yy) + '/' + str(yy+1) for yy in range(10, 23)],
    locations= ['Entire Network'],
    age_labels = ['Overall']
  )

  burden_adj = dat[dat.location == 'Entire Network'] \
    .groupby('season')['inc'] \
    .sum()
  burden_adj = burden_adj.reset_index()
  burden_adj.columns = ['season', 'cum_rate']

  us_census = load_us_census().query("location == 'US'").drop('location', axis=1)
  burden_adj = pd.merge(burden_adj, us_census, on='season')

  burden_estimates = load_hosp_burden()
  burden_adj = pd.merge(burden_adj, burden_estimates, on='season')

  burden_adj['reported_burden_est'] = burden_adj['cum_rate'] * burden_adj['pop'] / 100000
  burden_adj['adj_factor'] = burden_adj['hosp_burden'] / burden_adj['reported_burden_est']

  return burden_adj


def fill_missing_flusurv_dates_one_location( location_df):
  df = location_df.set_index('wk_end_date') \
    .asfreq('W-sat') \
    .reset_index()
  fill_cols = ['agg_level', 'location', 'season', 'pop', 'source']
  fill_cols = [c for c in fill_cols if c in df.columns]
  df[fill_cols] = df[fill_cols].fillna(axis=0, method='ffill')
  return df


def load_flusurv_rates(
                        burden_adj=True,
                        locations=['California', 'Colorado', 'Connecticut', 'Entire Network',
                                  'Georgia', 'Maryland', 'Michigan', 'Minnesota', 'New Mexico',
                                  'New York - Albany', 'New York - Rochester', 'Ohio', 'Oregon',
                                  'Tennessee', 'Utah']
                      ):
  # read flusurv data and do some minimal preprocessing
  dat = load_flusurv_rates_base(
    seasons = ['20' + str(yy) + '/' + str(yy+1) for yy in range(10, 23)],
    locations = locations,
    age_labels = ['Overall']
  )
  
  # if requested, make adjustments for overall season burden
  if burden_adj:
    hosp_burden_adj = calc_hosp_burden_adj()
    dat = pd.merge(dat, hosp_burden_adj, on='season')
    dat['inc'] = dat['inc'] * dat['adj_factor']
  
  # fill in missing dates
  gd = dat.groupby('location')
  
  dat = pd.concat(
    [fill_missing_flusurv_dates_one_location(df) for _, df in gd],
    axis = 0)
  dat = dat[['agg_level', 'location', 'season', 'season_week', 'wk_end_date', 'inc', 'source']]
  
  return dat


def load_who_nrevss_positive():
  dat = pd.read_csv('data-raw/influenza-who-nrevss/who-nrevss.csv',
                    encoding='ISO-8859-1',
                    engine='python')
  dat = dat[['region_type', 'region', 'year', 'week', 'season', 'season_week', 'percent_positive']]
  
  dat.rename(columns={'region_type': 'agg_level', 'region': 'location'},
            inplace=True)
  dat['agg_level'] = np.where(dat['agg_level'] == 'National',
                              'national',
                              dat['agg_level'].str[:-1].str.lower())
  return dat


def load_ilinet(
                response_type='rate',
                scale_to_positive=True,
                drop_pandemic_seasons=True,
                burden_adj=False):
  # read ilinet data and do some minimal preprocessing
  files = ['data-raw/influenza-ilinet/ilinet_state.csv']
  dat = pd.concat(
    [ pd.read_csv(f, encoding='ISO-8859-1', engine='python') for f in files ],
    axis = 0)
  
  if response_type == 'rate':
    dat['inc'] = np.where(dat['region_type'] == 'States',
                          dat['unweighted_ili'],
                          dat['weighted_ili'])
  else:
    dat['inc'] = dat.ilitotal

  dat['wk_end_date'] = pd.to_datetime(dat['week_start']) + pd.Timedelta(6, 'days')
  dat = dat[['region_type', 'region', 'year', 'week', 'season', 'season_week', 'wk_end_date', 'inc']]
  dat.rename(columns={'region_type': 'agg_level', 'region': 'location'},
            inplace=True)
  dat = dat.sort_values(by=['season', 'season_week'])

  # for early seasons, drop out-of-season weeks with no reporting
  early_seasons = [str(yyyy) + '/' + str(yyyy + 1)[2:] for yyyy in range(1997, 2002)]
  early_in_season_weeks = [w for w in range(10, 43)]
  first_report_season = ['2002/03']
  first_report_in_season_weeks = [w for w in range(10, 53)]
  dat = dat[
    (dat.season.isin(early_seasons) & dat.season_week.isin(early_in_season_weeks)) |
    (dat.season.isin(first_report_season) & dat.season_week.isin(first_report_in_season_weeks)) |
    (~dat.season.isin(early_seasons + first_report_season))]
  
  # region 10 data prior to 2010/11 is bad, drop it
  dat = dat[
    ~(dat['season'] < '2010/11')
  ]
  dat['agg_level'] = dat['agg_level'].replace('States', 'state')
  dat['city'] = np.where(dat['location'].isna(), '', 
                       np.where(dat['location'] == 'New York City', 'NEW_YORK', ''))
  dat['location'] = np.where(dat['location'] == 'New York City', 'New York', dat['location'])
  
  

  if scale_to_positive:
    dat = pd.merge(
      left=dat,
      right=load_who_nrevss_positive(),
      how='left',
      on=['agg_level', 'location', 'season', 'season_week'])
    dat['inc'] = dat['inc'] * dat['percent_positive'] / 100.0
    dat.drop('percent_positive', axis=1)


  if drop_pandemic_seasons:
    dat.loc[dat['season'].isin(['2008/09', '2009/10', '2020/21', '2021/22']), 'inc'] = np.nan

  dat = dat[['agg_level', 'city', 'location', 'season', 'season_week', 'wk_end_date', 'inc']]
  dat = dat[dat['location'] != 'Commonwealth of the Northern Mariana Islands']
  dat['source'] = 'ilinet'  

  fips_mappings = pd.read_csv('data-raw/fips-mappings/fips_mappings.csv')
  dat = dat.merge(fips_mappings, how = 'left', 
                  left_on='location', right_on= 'location_name')\
                  .drop(columns=['agg_level', 'location_y', 'location_name', 'hhs_region'])\
                  .rename(columns={'abbreviation': 'state', 'location_x':'location'})
  
  dat = dat[['state', 'city', 'season', 'season_week', 'wk_end_date', 'inc', 'source']]                
  return(dat)



def load_hhs( rates=True, drop_pandemic_seasons=True, as_of=None):
  
  
  dat = pd.read_csv('data-raw/influenza-hhs/hhs_complete.csv')
  dat.rename(columns={'date': 'wk_end_date'}, inplace=True)

  ew_str = dat.apply(date_to_ew_str, axis=1)
  dat['season'] = convert_epiweek_to_season(ew_str)
  dat['season_week'] = convert_epiweek_to_season_week(ew_str)
  dat = dat.sort_values(by=['season', 'season_week'])
  
  if rates:
    pops = load_us_census()
    dat = dat.merge(pops, on = ['location', 'season'], how='left') \
      .assign(inc=lambda x: x['inc'] / x['pop'] * 100000)

  dat['wk_end_date'] = pd.to_datetime(dat['wk_end_date'])
  
  dat['agg_level'] = np.where(dat['location'] == 'US', 'national', 'state')
  dat = dat[['agg_level', 'location', 'season', 'season_week', 'wk_end_date', 'inc']]
  dat['source'] = 'hhs'
  return dat


def load_nhsn_state():
  dat = pd.read_csv('data-raw/influenza-nhsn/state_level_data.csv')
  dat.rename(columns={'week_date': 'wk_end_date'}, inplace=True)

  ew_str = dat.apply(date_to_ew_str, axis=1)
  dat['season'] = convert_epiweek_to_season(ew_str)
  dat['season_week'] = convert_epiweek_to_season_week(ew_str)
  dat = dat.sort_values(by=['season', 'season_week'])
  dat['inc'] = dat['confirmed_influenza']/(dat['state_2023']/ 100000)
  dat['wk_end_date'] = pd.to_datetime(dat['wk_end_date'])-pd.Timedelta(days=1)
  dat['city'] = ''
  dat = dat[['state', 'city', 'season', 'season_week', 'wk_end_date', 'inc']]
  dat['source'] = 'nhsn_state'
  return dat

def load_nhsn_city():
  dat = pd.read_csv('data-raw/influenza-nhsn/city_level_hhs.csv')
  dat.rename(columns={'collection_week': 'wk_end_date'}, inplace=True)
  dat = dat[dat['city_2023'].notna()]
  ew_str = dat.apply(date_to_ew_str, axis=1)
  ew_str
  dat['season'] = convert_epiweek_to_season(ew_str)
  dat['season_week'] = convert_epiweek_to_season_week(ew_str)
  dat = dat.sort_values(by=['season', 'season_week'])
  dat['inc'] = dat['influenza_7_day_sum']/(dat['city_2023']/ 100000)
  dat['wk_end_date'] = pd.to_datetime(dat['wk_end_date'])-pd.Timedelta(days=1)
  dat = dat[['state', 'city', 'season', 'season_week', 'wk_end_date', 'inc']]
  dat['source'] = 'nhsn_city'
  return dat


city_mapping = {
    'New York - Albany': 'Albany',
    'New York - Rochester': 'Rochester'    
}

state_mapping = {
    'California': 'CA',
    'Colorado': 'CO',
    'Connecticut': 'CT',
    'Georgia': 'GA',
    'Maryland': 'MD',
    'Michigan': 'MI',
    'Minnesota': 'MN',
    'New Mexico': 'NM',
    'New York - Albany': 'NY',
    'New York - Rochester': 'NY',
    'Ohio': 'OH',
    'Oregon': 'OR',
    'Tennessee': 'TN',
    'Utah': 'UT'
}



def load_flusurv_rates_city( burden_adj=True,
                      locations=['California', 'Colorado', 'Connecticut',
                              'Georgia', 'Maryland', 'Michigan', 'Minnesota', 'New Mexico',
                              'New York - Albany', 'New York - Rochester', 'Ohio', 'Oregon',
                              'Tennessee', 'Utah'],
                      ):
  
  

  # read flusurv data and do some minimal preprocessing
  dat = load_flusurv_rates_base(
      seasons = ['20' + str(yy) + '/' + str(yy+1) for yy in range(10, 23)],
    locations = locations,
    age_labels = ['Overall']
  )
  
  # if requested, make adjustments for overall season burden
  if burden_adj:
    hosp_burden_adj = calc_hosp_burden_adj()
    dat = pd.merge(dat, hosp_burden_adj, on='season')
    dat['inc'] = dat['inc'] * dat['adj_factor']
  
  # fill in missing dates
  gd = dat.groupby('location')
  
  dat = pd.concat(
    [fill_missing_flusurv_dates_one_location(df) for _, df in gd],
    axis = 0)
  dat['state'] = dat['location'].map(state_mapping)
  dat['city'] = dat['location'].map(city_mapping).fillna('')

  dat = dat[['agg_level', 'state', 'city', 'season', 'season_week', 'wk_end_date', 'inc', 'source']]
  
  return dat

def state_city_population():
  dat = pd.read_csv('data-raw/influenza-nhsn/city_level_hhs.csv')
  dat = dat[dat['city_2023'].notna()]
  dat = dat[['state', 'city', 'state_2023', 'city_2023']]
  unique_dat = dat.drop_duplicates()
  return(unique_dat)




def load_agg_transform_ilinet( fips_mappings, **ilinet_kwargs):
  df_ilinet_full = load_ilinet(**ilinet_kwargs)
  # df_ilinet_full.loc[df_ilinet_full['inc'] < np.exp(-7), 'inc'] = np.exp(-7)
  df_ilinet_full['inc'] = (df_ilinet_full['inc'] + np.exp(-7)) * 4
  
  # aggregate ilinet sites in New York to state level,
  # mainly to facilitate adding populations
  ilinet_nonstates = ['National', 'Region 1', 'Region 2', 'Region 3',
                      'Region 4', 'Region 5', 'Region 6', 'Region 7',
                      'Region 8', 'Region 9', 'Region 10']
  df_ilinet_by_state = df_ilinet_full \
    .loc[(~df_ilinet_full['location'].isin(ilinet_nonstates)) &
        (df_ilinet_full['location'] != '78')] \
    .assign(state = lambda x: np.where(x['location'].isin(['New York', 'New York City']),
                                      'New York',
                                      x['location'])) \
    .assign(state = lambda x: np.where(x['state'] == 'Commonwealth of the Northern Mariana Islands',
                                      'Northern Mariana Islands',
                                      x['state'])) \
    .merge(
      fips_mappings.rename(columns={'location': 'fips'}),
      left_on='state',
      right_on='location_name') \
    .groupby(['state', 'fips', 'season', 'season_week', 'wk_end_date', 'source']) \
    .apply(lambda x: pd.DataFrame({'inc': [np.mean(x['inc'])]})) \
    .reset_index() \
    .drop(columns = ['state', 'level_6']) \
    .rename(columns = {'fips': 'location'}) \
    .assign(agg_level = 'state')
  
  df_ilinet_nonstates = df_ilinet_full.loc[df_ilinet_full['location'].isin(ilinet_nonstates)].copy()
  df_ilinet_nonstates['location'] = np.where(df_ilinet_nonstates['location'] == 'National',
                                            'US',
                                            df_ilinet_nonstates['location'])
  df_ilinet = pd.concat(
    [df_ilinet_nonstates, df_ilinet_by_state],
    axis = 0)
  
  return df_ilinet


def load_agg_transform_flusurv( fips_mappings, **flusurvnet_kwargs):
  df_flusurv_by_site = load_flusurv_rates(**flusurvnet_kwargs)
  # df_flusurv_by_site.loc[df_flusurv_by_site['inc'] < np.exp(-3), 'inc'] = np.exp(-3)
  df_flusurv_by_site['inc'] = (df_flusurv_by_site['inc'] + np.exp(-3)) / 2.5
  
  # aggregate flusurv sites in New York to state level,
  # mainly to facilitate adding populations
  df_flusurv_by_state = df_flusurv_by_site \
    .loc[df_flusurv_by_site['location'] != 'Entire Network'] \
    .assign(state = lambda x: np.where(x['location'].isin(['New York - Albany', 'New York - Rochester']),
                                      'New York',
                                      x['location'])) \
    .merge(
      fips_mappings.rename(columns={'location': 'fips'}),
      left_on='state',
      right_on='location_name') \
    .groupby(['fips', 'season', 'season_week', 'wk_end_date', 'source']) \
    .apply(lambda x: pd.DataFrame({'inc': [np.mean(x['inc'])]})) \
    .reset_index() \
    .drop(columns = ['level_5']) \
    .rename(columns = {'fips': 'location'}) \
    .assign(agg_level = 'state')
  
  df_flusurv_us = df_flusurv_by_site.loc[df_flusurv_by_site['location'] == 'Entire Network'].copy()
  df_flusurv_us['location'] = 'US'
  df_flusurv = pd.concat(
    [df_flusurv_us, df_flusurv_by_state],
    axis = 0)
  
  return df_flusurv


def load_data( sources=None, flusurvnet_kwargs=None, hhs_kwargs=None, ilinet_kwargs=None,
              power_transform='4rt'):
  '''
  Load influenza data and transform to a scale suitable for input to models.

  Parameters
  ----------
  sources: None or list of sources
      data sources to collect. Defaults to ['flusurvnet', 'hhs', 'ilinet'].
      If provided as a list, must be a subset of the defaults.
  flusurvnet_kwargs: dictionary of keyword arguments to pass on to `load_flusurv_rates`
  hhs_kwargs: dictionary of keyword arguments to pass on to `load_hhs`
  ilinet_kwargs: dictionary of keyword arguments to pass on to `load_ilinet`
  power_transform: string specifying power transform to use: '4rt' or `None`

  Returns
  -------
  Pandas DataFrame
  '''
  if sources is None:
      sources = ['flusurvnet', 'nhsn_state', 'nhsn_city', 'ilinet']
  
  if flusurvnet_kwargs is None:
      flusurvnet_kwargs = {}
  
  if hhs_kwargs is None:
      hhs_kwargs = {}
  
  if ilinet_kwargs is None:
      ilinet_kwargs = {}
  
  if power_transform not in ['4rt', None]:
      raise ValueError('Only None and "4rt" are supported for the power_transform argument.')
  
  us_census = load_us_census()
  
  aa = pd.read_csv('data-raw/fips-mappings/fips_mappings.csv',
                      encoding='ISO-8859-1',
                      engine='python')
  us_census = us_census.merge(aa, how = 'left', on = 'location')\
      .rename(columns={'abbreviation': 'state'})\
      .drop(columns=['location_name', 'hhs_region'])
  city_census = pd.read_csv("data-raw/influenza-nhsn/city_level_hhs.csv")
  city_census = city_census[city_census['city_2023'].notna()]
  city_census = city_census[['state', 'city', 'city_2023']].drop_duplicates()
  city_census.rename(columns={'city_2023': 'pop'}, inplace=True)
  city_census['city'] = city_census['city'].str.replace(' ', '_')
  

  if 'nhsn_state' in sources:
    df_nhsn_state = load_nhsn_state()
    df_nhsn_state = df_nhsn_state[df_nhsn_state['season'].isin(['2022/23', '2023/24'])] 
    df_nhsn_state['state_city'] = df_nhsn_state['state']
    df_nhsn_state = df_nhsn_state.merge(us_census, how='left', on=['state', 'season'])
  else:
    df_nhsn_state = None

  if 'nhsn_city' in sources:
    df_nhsn_city = load_nhsn_city()
    df_nhsn_city = df_nhsn_city[df_nhsn_city['season'].isin(['2022/23', '2023/24'])]
    df_nhsn_city['city'] = df_nhsn_city['city'].str.replace(' ', '_')
    df_nhsn_city['state_city'] = df_nhsn_city['state'] + '_' + df_nhsn_city['city']
    df_nhsn_city = df_nhsn_city.merge(city_census, how='left', on=['state', 'city'])
    group_counts = df_nhsn_city.groupby('state_city').size()
    filtered_counts = group_counts[group_counts < 91]
    unique_states = filtered_counts.index
    df_nhsn_city = df_nhsn_city[~df_nhsn_city['state_city'].isin(unique_states)]
  else:
    df_nhsn_city = None
  
  if 'flusurvnet' in sources:
    df_flusurv_by_site_city = load_flusurv_rates_city()
    df_flusurv_by_site_city = df_flusurv_by_site_city[df_flusurv_by_site_city['agg_level'].isin(['site'])]
    df_flusurv_by_site_city['city'] = df_flusurv_by_site_city['city'].str.upper()
    df_flusurv_by_site_city['state_city'] = df_flusurv_by_site_city.apply(
        lambda row: f"{row['state']}_{row['city'].replace(' ', '_')}" if row['city'] != '' else row['state'],
        axis=1) 
    df_original_columns = df_flusurv_by_site_city[['state', 'city', 'state_city']].drop_duplicates()


    df_flusurv_by_site_city = df_flusurv_by_site_city.groupby(['state_city', 'season', 'season_week', 'wk_end_date', 'source']) \
        .apply(lambda x: pd.DataFrame({'inc': [np.mean(x['inc'])]})) \
        .reset_index() \
        .drop(columns = ['level_5'])

    df_flusurv_by_site_city = df_flusurv_by_site_city.merge(df_original_columns, on='state_city', how='left')
    df_nhsn_state = df_nhsn_state.merge(us_census, how='left', on=['state', 'season'])
    df_flusurv_state = df_flusurv_by_site_city[df_flusurv_by_site_city['city'] == '']
    df_flusurv_city = df_flusurv_by_site_city[df_flusurv_by_site_city['city'] != '']

    df_flusurv_state = df_flusurv_state.merge(us_census, how='left', on=['state', 'season'])
    df_flusurv_city = df_flusurv_city.merge(city_census, how='left', on=['state', 'city'])
  else:
    df_flusurv_state = None
    df_flusurv_city = None

  if 'ilinet' in sources:
    df_ilinet_state_city = load_ilinet()
    df_ilinet_state_city = df_ilinet_state_city.dropna(subset=['inc'])
    df_ilinet_state = df_ilinet_state_city[df_ilinet_state_city['city'] == '']
    df_ilinet_city = df_ilinet_state_city[df_ilinet_state_city['city'] != '']
    df_ilinet_state['state_city'] = df_ilinet_state['state']
    df_ilinet_state = df_ilinet_state.merge(us_census, how='left', on=['state', 'season'])
    df_ilinet_city = df_ilinet_city.merge(city_census, how='left', on=['state', 'city'])
    df_ilinet_city['state_city'] = df_ilinet_city['state'] + '_' + df_ilinet_city['city'] 
  else:
    df_ilinet_state = None
    df_ilinet_city = None
  
  
  df = pd.concat(
      [df_nhsn_state, df_nhsn_city, df_flusurv_state, df_flusurv_city, df_ilinet_state, df_ilinet_city],
      axis=0).sort_values(['source', 'state_city', 'wk_end_date'])
  df = df[df['pop']>=100000]
  # log population
  df['log_pop'] = np.log(df['pop'])

  # process response variable:
  # - fourth root transform to stabilize variability
  # - divide by location- and source- specific 95th percentile
  # - center relative to location- and source- specific mean
  #   (note non-standard order of center/scale)
  if power_transform is None:
      df['inc_trans'] = df['inc'] + 0.01
  elif power_transform == '4rt':
      df['inc_trans'] = (df['inc'] + 0.01)**0.25
  
  df['inc_trans_scale_factor'] = df \
      .assign(
          inc_trans_in_season = lambda x: np.where((x['season_week'] < 10) | (x['season_week'] > 45),
                                                    np.nan,
                                                    x['inc_trans'])) \
      .groupby(['source', 'state_city'])['inc_trans_in_season'] \
      .transform(lambda x: x.quantile(0.95))
  
  df['inc_trans_cs'] = df['inc_trans'] / (df['inc_trans_scale_factor'] + 0.01)
  df['inc_trans_center_factor'] = df \
      .assign(
          inc_trans_cs_in_season = lambda x: np.where((x['season_week'] < 10) | (x['season_week'] > 45),
                                                      np.nan,
                                                      x['inc_trans_cs'])) \
      .groupby(['source', 'state_city'])['inc_trans_cs_in_season'] \
      .transform(lambda x: x.mean())
  df['inc_trans_cs'] = df['inc_trans_cs'] - df['inc_trans_center_factor']
  df.drop(columns=['state', 'city'])
  return(df)