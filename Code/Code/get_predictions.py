import pandas as pd
import xarray as xr
import os
import numpy as np
import argparse


def get_data_for_station(datafile_in, days_into_future):
    glofas_data = xr.open_dataset(datafile_in)

    glofas_data = glofas_data.sel(ensemble=slice(1, 10), step=days_into_future + 1)
    glofas_data = glofas_data.squeeze(dim='size', drop=True)
    glofas_data = glofas_data.dis.median(dim='ensemble')
    glofas_data = glofas_data.resample(time='1D').interpolate('linear')

    df_out = pd.DataFrame({'dis': glofas_data.values}, index=glofas_data.time.values)

    return df_out


if __name__ == '__main__':

    argparser = argparse.ArgumentParser()
    argparser.add_argument('station', type=str, help='name of station')
    argparser.add_argument('threshold', type=float, help='threshold')
    argparser.add_argument('fwd_looking', type=int, help='nr of forward looking days')
    args = argparser.parse_args()

    df_stations = pd.read_csv('stations.csv')
    sr_mapping = pd.read_csv('sr_mapping.csv')
    floods = pd.read_csv('floods.csv')

    datafile = df_stations.query(f'station=="{args.station}"').filename.values[0]
    glofas_df = get_data_for_station(datafile, args.fwd_looking)
    df_out = glofas_df.groupby(glofas_df.index.year).max()
    df_out = df_out.loc[2003:]
    df_out.columns = ['maximum_discharge']
    dis_threshold = glofas_df.quantile(args.threshold/100).values[0]
    df_out['prediction'] = df_out.maximum_discharge.apply(lambda d: 1 if d > dis_threshold else 0)
    regions = sr_mapping.query(f'station_name=="{args.station.lower()}"').Region.values
    for region in regions:
        nr_floods_predicted = df_out.prediction.sum()
        df_out[region] = floods[region].values
        flood_years = df_out[df_out[region] == 1].index.values
        nr_hits = df_out.loc[flood_years, 'prediction'].sum()
        nr_misses = len(flood_years) - nr_hits
        nr_false_alarms = nr_floods_predicted - nr_hits
        print(region, nr_hits, nr_misses, nr_false_alarms)
