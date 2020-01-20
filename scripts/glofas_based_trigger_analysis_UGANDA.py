# -*- coding: utf-8 -*-
"""
Created on Sun Oct 20 20:24:03 2019

@authors: ABucherie
"""
# import regionmask

#%%
# setting up your environment

import xarray as xr
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
from os import listdir
from os.path import isfile, join
import seaborn as sns
import geopandas as gpd
from shapely.geometry import Point
from pandas.plotting import register_matplotlib_converters
import datetime
from sklearn.metrics import confusion_matrix

#%% functions definition 
#Creating a fonction to normalize result

def normalize(df):
    result = df.copy()
    for feature_name in df.columns:
        max_value = df[feature_name].max()
        min_value = df[feature_name].min()
        result[feature_name] = (df[feature_name] - min_value) / (max_value - min_value)
    return result

# compute confusion matrix and performance index functions

def calc_pod(obs, pred):
    corr_neg, false_al, misses, hits = confusion_matrix(obs, pred).ravel()    
    POD = hits / (hits + misses)
    return POD

def calc_far(obs, pred):
    corr_neg, false_al, misses, hits = confusion_matrix(obs, pred).ravel()    
    FAR = false_al / (hits + false_al)
    return FAR
    
def calc_pofd(obs, pred):
    corr_neg, false_al, misses, hits = confusion_matrix(obs, pred).ravel()    
    POFD = false_al / (false_al + corr_neg)
    return POFD

def calc_csi(obs, pred):
    corr_neg, false_al, misses, hits = confusion_matrix(obs, pred).ravel()    
    CSI = hits / (hits + false_al + misses)
    return CSI

def calc_performance_scores(obs, pred):
    output = {}
    output['pod'] = calc_pod(obs, pred)
    output['far'] = calc_far(obs, pred)
    output['pofd'] = calc_pofd(obs, pred)
    output['csi'] = calc_csi(obs, pred)
    
    output = pd.Series(output)
    return output
     
#%%
# open a glofas ncdf dataset on a seleted area in shapefile, then return in Csv all the glofas station data inside the shapefile.   
mypath='C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/Glofas_Africa_nc'
onlyfiles = [ f for f in listdir(mypath) if isfile(join(mypath,f)) ]

# load admin shapefile for Uganda
admin_shp = gpd.read_file('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/shapes/uga_admbnda_adm2/uga_admbnda_adm2_UBOS_v2.shp')  # load admin shape file for Mali
di={}
location_list=[]
stations_list=[]
Lat_list=[]
Lon_list=[]

#%% takes time to run  !! 5 minutes = find in the glofas Africal global data, the station that are in the Uganda shapefile

for files in onlyfiles:
    Filename = os.path.join(mypath,files)
    sna=files.split('_')[5]
    data = xr.open_dataset(Filename)
    stid=files.split('_')[4]
    point =Point(data['plon'].values[0],data['plat'].values[0])
    Lon=data['plon'].values[0]
    Lat=data['plat'].values[0]
    if point.intersects(admin_shp['geometry'].unary_union): # check if Glofas station is in the polygon
        stations_list.append(stid)
        location_list.append(sna)
        Lon_list.append(Lon)
        Lat_list.append(Lat)
        di[stid]=data 
    data.close()
 
#%% SAVE the selected glofas stations .nc files to .csv 
df_total=pd.DataFrame(columns=['station', 'time', 'dis'])

for station in stations_list:
    # create .cv file per station of glofas  (every 3 days mean ensemble)
    df_y=pd.DataFrame(columns=['time', 'dis'])
    flow=di[station]['dis'].median(dim='ensemble').sel(step=1).drop(['step']) # median of esemble variables
    df_y['time']=flow['time'].values         
    df_y['dis']=pd.Series(flow.values.flatten())  
    df_y=df_y.set_index('time')
    df_y.to_csv(('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/glofas/GLOFAS_data_for_%s.csv' %station))
    
    # create a combined .cv file for all station station of glofas with filled data every day
    df_z=pd.DataFrame(columns=['station', 'time', 'dis']) 
    flow=di[station]['dis'].median(dim='ensemble').sel(step=1).drop(['step']) # median of esemble variables
    flow_fill=flow.resample(time='1D').ffill()
    df_z['time']=flow_fill['time'].values         
    df_z['dis']=pd.Series(flow_fill.values.flatten())  
    df_z['station']=station
    df_total = df_total.append(df_z, ignore_index=True)
    
df_total=df_total.dropna()
df_total.to_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/glofas/GLOFAS_fill_allstation.csv', index=False)

#%% Extracting Station information with lat and lon in a csv file and computing Glofas quantiles per station in these table. Save the table as .csv
# Q90 correspond to a return period of (1/0.1) = 10 years    
# Q95 correspond to a return period of (1/0.05) = 20 years  
# Q98 correspond to a return period of (1/0.02) = 50 years  
    
df_station=pd.DataFrame(columns=['Station', 'location', 'Lat','Lon', 'Q90', 'Q95', 'Q98'])
df_station = df_station[['Station']].rename(columns={'Station': 'station'})

for i in range(len(location_list)):
    station= stations_list[i]  
    df_station.loc[i,'station']= stations_list[i]
    df_station.loc[i,'location']= location_list[i]
    df_station.loc[i,'Lon']= Lon_list[i]
    df_station.loc[i,'Lat']= Lat_list[i]
    try:                                

        gl_station=pd.read_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/glofas/GLOFAS_data_for_%s.csv' %station)
        df_station.loc[i,'Q90']= gl_station.dis.quantile(0.9)
        df_station.loc[i,'Q95']= gl_station.dis.quantile(0.95)
        df_station.loc[i,'Q98']= gl_station.dis.quantile(0.98)
    except:
        continue
    
df_station.to_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/shapes/uga_glofas_stations/uga_glofas_station.csv')

    
#%% Opening files

#Open the flood impact data .csv file and create a dataframe
flood_events=pd.read_csv("C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/impact_data.csv", encoding='latin-1')  
flood_events['Date']= pd.to_datetime(flood_events['Date'], format='%m/%d/%Y')                     # transforming date from string to datetime                                                        # create a list of event dates
flood_events.index=flood_events['Date']
flood_events = flood_events[['Area', 'flood']].rename(columns={'Area': 'district'})
#flood_events = flood_events[['Area', 'flood']].reset_index().rename(columns={'Date': 'time', 'Area': 'district'})

#  open the impacted_area and Glofas related stations per district files
df_dg=pd.read_csv("C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/AFFECTED_DIST_with_glofas_ABU.csv", encoding='latin-1')  
df_dg_long = df_dg[['name', 'Glofas_st', 'Glofas_st2', 'Glofas_st3', 'Glofas_st4']].melt(id_vars='name', var_name='glofas_n', value_name='station').drop('glofas_n', 1).dropna()
df_dg_long = df_dg_long.rename(columns = {'name': 'district'})
df_dg=df_dg.set_index('name')

#%% create a plot per district, only for the district having recorded impacts,  and for the related glofas stations for the district

Affected_admin2=np.unique(flood_events['district'].values)  

for districts in Affected_admin2: # for each district of Uganda
    print('############')
    print(districts)
    fe_district=flood_events[flood_events['district']==districts]
    df_event1=fe_district['flood'] 
    df_y=pd.DataFrame()
    st= df_dg.loc[districts, 'Glofas_st':'Glofas_st4']
    st= st.dropna()

    for j in range(0,len(st)) :  # for each related Glofas station associated to the district
        print(st[j])
        flow=di[st[j]]['dis'].median(dim='ensemble').sel(step=1).drop(['step']) # median of esemble variables
        flow_=flow.resample(time='1D').interpolate('linear')     
        df_y[st[j]]=pd.Series(flow_.values.flatten())  
        df_y['time']=flow_['time'].values

    try:
        dff=normalize(df_y.drop('time',axis=1))
        dff['time']=df_y['time']
        df = dff.melt('time', var_name='Stations',  value_name='dis')
        
        fig = plt.figure(figsize=(16, 12),frameon=False, dpi=400)
        ax1 = fig.add_subplot(1, 1, 1)
        ax1.set_xlabel('Time (year)', fontsize=18)
        ax1.set_ylabel('Scale flow', fontsize=18)
        sns.lineplot(x="time", y="dis",  hue="Stations", data=df,ax=ax1)
        for index, row in df_event1.iteritems():
            if row==1:
                ax1.axvline(x=index, color='y', linestyle='--')  
                
        ax1.set_title( '(Glofas Test for Admin =%s'%districts,fontsize=20,bbox=dict(facecolor='red', alpha=0.5))
        fig.savefig('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Glofas_Analysis/flow_impact_%s.png' %districts)
        plt.clf()
    except:
        continue
  
 #%%  Joining together tables and extracting discharge data to create a prediction model table (df_model)
    
    

impact_floods = flood_events.reset_index().rename(columns={'Date': 'time'})
#impact_floods = flood_events[['Area', 'flood']].reset_index().rename(columns={'Date': 'time', 'Area': 'district'})    
    
df_model = pd.merge(df_total, df_dg_long, how='left', on='station').dropna()
df_model = pd.merge(df_model, impact_floods , how='left', on=['time', 'district'])
df_model = pd.merge(df_model, df_station[['station','Q90', 'Q95','Q98']] , how='left', on='station')

df_model['dis_min1'] = df_model['dis'].shift(1).fillna(0)
df_model['dis_min2'] = df_model['dis'].shift(2).fillna(0)
df_model['dis_min3'] = df_model['dis'].shift(3).fillna(0)
df_model['flood'] = df_model['flood'].fillna(0)

#create column of lag of Glofas (-1,-2 and -3 days)
df_model['Q90_pred']=np.where((
    (df_model['dis'] >= df_model['Q90']) |
    (df_model['dis_min1'] >= df_model['Q90']) | 
    (df_model['dis_min2'] >= df_model['Q90']) |
    (df_model['dis_min3'] >= df_model['Q90'])
    ), 1, 0)

df_model['Q95_pred']=np.where((
    (df_model['dis'] >= df_model['Q95']) |
    (df_model['dis_min1'] >= df_model['Q95']) | 
    (df_model['dis_min2'] >= df_model['Q95']) |
    (df_model['dis_min3'] >= df_model['Q95'])
    ), 1, 0)

df_model['Q98_pred']=np.where((
    (df_model['dis'] >= df_model['Q98']) |
    (df_model['dis_min1'] >= df_model['Q98']) | 
    (df_model['dis_min2'] >= df_model['Q98']) |
    (df_model['dis_min3'] >= df_model['Q98'])
    ), 1, 0)

#df_model.query('Q98_pred == 1')    #Tool to do a query in the df_model

#%% Calculating performance index of the prediction model and saving result in .csv
performance_scores=pd.DataFrame(columns=['district','station', 'pod','far','pofd','csi'])
quantiles = ['Q90_pred', 'Q95_pred', 'Q98_pred']

for quantile in quantiles:
    perf= df_model.groupby(['district', 'station']).apply(lambda row: calc_performance_scores(row['flood'], row[quantile])).reset_index()
    perf['quantile'] = quantile
    performance_scores=performance_scores.append(perf)
    
# adding the number of flood impact data per district
floods_per_district = impact_floods.groupby('district')['flood'].count()
performance_scores = pd.merge(floods_per_district, performance_scores, how='left', on=['district'])
performance_scores = performance_scores.rename(columns={ 'flood': 'nb_event'})
performance_scores = performance_scores[['district','station','nb_event','quantile', 'pod','far','pofd','csi']]

performance_scores.to_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Performance_scores/uga_glofas_performance_score.csv', index=False)








    

