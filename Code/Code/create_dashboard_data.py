import pandas as pd
import xarray as xr
import os
import numpy as np
import tqdm
import matplotlib.pyplot as plt


def get_floods_and_regions():
    data_out = pd.read_csv('/Users/rodekruis/projects/ibf/data/flood_year_per_district.txt')
    data_out.set_index('Flood_year', inplace=True)

    return data_out, data_out.columns.values


def get_station_names_and_locations(datafiles_in, datadir_in):
    ids = []
    names = []
    lats = []
    lons = []
    files = []

    for f in datafiles_in:
        filename = f.split('_')
        ids.append(filename[4])
        names.append(filename[5])
        files.append(os.path.join(datadir_in, f))
        xdata = xr.open_dataset(os.path.join(datadir_in, f))
        lats.append(xdata.plat.values[0])
        lons.append(xdata.plon.values[0])
        xdata.close()

    return pd.DataFrame({'station_id': ids, 'station': names, 'latitude': lats, 'longitude': lons,
                         'filename': files})


def get_data_for_station(station_in, days_into_future):
    datafile = df_stations.query(f'station=="{station_in}"').filename.values[0]
    glofas_data = xr.open_dataset(datafile)

    glofas_data = glofas_data.sel(ensemble=slice(1, 10), step=days_into_future+1)
    glofas_data = glofas_data.squeeze(dim='size', drop=True)
    glofas_data = glofas_data.dis.median(dim='ensemble')
    glofas_data = glofas_data.resample(time='1D').interpolate('linear')

    df_out = pd.DataFrame({'dis': glofas_data.values}, index=glofas_data.time.values)

    return df_out


def get_predictions_for_station(station_in, thresholds_in, days_into_future):

    df_station = get_data_for_station(station_in, days_into_future)

    df_out = df_station.groupby(df_station.index.year).max()
    df_out.columns = ['maximum_discharge']
    df_out['year'] = df_out.index.values.copy()

    for thr in thresholds_in:
        dis_threshold = df_station.quantile(thr/100).values[0]
        df_out['thr_{}'.format(thr)] = df_out.maximum_discharge.apply(lambda d: 1 if d > dis_threshold else 0)

    return df_out


def get_predictions_for_all_stations(stations_in, thresholds_in, days_into_future):

    df_out = None

    for st in stations_in:
        df_station_preds = get_predictions_for_station(st, thresholds_in, days_into_future)
        df_station_preds['station'] = st
        if df_out is None:
            df_out = df_station_preds.copy()
        else:
            df_out = df_out.append(df_station_preds)

    return df_out


def get_station_region_mapping():
    data_out = pd.read_csv('/Users/rodekruis/projects/ibf/data/station_district_mapping.csv', sep=';')
    data_out['station_name'] = data_out.Station.apply(lambda x: x[:-13].lower()
                                                      if x.endswith('_st_districts') else x.lower())
    data_out['station_name'] = data_out.station_name.str.replace('itzehitezhi', 'itezhitezhi')
    data_out['Region'] = data_out.Region.str.replace("Shangombo", "Shang'ombo")
    data_out['Region'] = data_out.Region.str.replace("Itezhi Tezhi", "Itezhi-Tezhi")
    data_out['Region'] = data_out.Region.str.replace("chienge", "Chienge (Chiengi)")

    return data_out


def create_output(df_stations_in, df_floods_in, mapping_in, thresholds_in, df_all_preds_in):
    nr_stations = len(df_stations_in)
    nr_years = len(df_floods_in)
    nr_regions = len(mapping_in)
    nr_thresholds = len(thresholds_in)

    len_df = nr_regions * nr_years * nr_thresholds
    temp_input = np.zeros(len_df)

    df_out = pd.DataFrame({'station': None, 'region': None, 'year': temp_input, 'threshold': 0, 'pred': 0, 'truth': 0})

    idx = 0
    for st in tqdm.tqdm(df_stations_in.station.values):
        for yr in df_floods_in.index.values:
            preds = df_all_preds_in.query('station=="{}" & year=="{}"'.format(st, yr))
            for thr in thresholds_in:
                for reg in mapping_in.query(f'station_name == "{st.lower()}"').Region.values:
                    df_out.at[idx, 'station'] = st
                    df_out.at[idx, 'region'] = reg
                    df_out.at[idx, 'year'] = yr
                    df_out.at[idx, 'threshold'] = thr
                    df_out.at[idx, 'pred'] = preds['thr_{}'.format(thr)].values[0]
                    df_out.at[idx, 'truth'] = df_floods_in.loc[yr, reg]
                    idx += 1

    return df_out


if __name__ == '__main__':
    # glofass data
    datadir = '/Users/rodekruis/projects/ibf/data/Glofas_new_datasets'
    thresholds = [80, 90, 95, 99]
    forward_looking_days = 0

    datafiles = [f for f in os.listdir(datadir) if os.path.isfile(os.path.join(datadir, f))]

    df_stations = get_station_names_and_locations(datafiles, datadir)
    df_floods, regions = get_floods_and_regions()
    sr_mapping = get_station_region_mapping()
    df_all_preds = get_predictions_for_all_stations(df_stations.station.values, thresholds, forward_looking_days)
    output = create_output(df_stations, df_floods, sr_mapping, thresholds, df_all_preds)
    output['fwd_looking'] = forward_looking_days

    for forward_looking_days in [4, 7]:
        df_all_preds = get_predictions_for_all_stations(df_stations.station.values, thresholds, forward_looking_days)
        output_temp = create_output(df_stations, df_floods, sr_mapping, thresholds, df_all_preds)
        output_temp['fwd_looking'] = forward_looking_days
        output = output.append(output_temp)

    output.to_csv('input_for_dashboard_limited.csv')

    # import sesd
    # station = 'Lukulu'
    # flow = get_data_for_station(station, 0)
    # regions = sr_mapping.query(f'station_name == "{station.lower()}"').Region.values
    # flow.at['2018-09-16'] = 10000
    # outliers_indices = sesd.esd(flow.values.squeeze(), max_anomalies=10)