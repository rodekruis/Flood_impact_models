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
#%% Creating a fonction to normalize result

def normalize(df):
    result = df.copy()
    for feature_name in df.columns:
        max_value = df[feature_name].max()
        min_value = df[feature_name].min()
        result[feature_name] = (df[feature_name] - min_value) / (max_value - min_value)
    return result
     
#%%
# open a glofas ncdf dataset on a seleted area in shapefile, then return in Csv all the glofas station data inside the shapefile.
    
mypath='C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/Glofas_Africa_nc'
onlyfiles = [ f for f in listdir(mypath) if isfile(join(mypath,f)) ]
#%%
# load admin shapefile for Uganda
admin_shp = gpd.read_file('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/shapes/uga_admbnda_adm2/uga_admbnda_adm2_UBOS_v2.shp')  # load admin shape file for Mali
di={}
location_list=[]
stations_list=[]
Lat_list=[]
Lon_list=[]

#%% takes time to run  !! = find in the glofas Africal global data, the station that are in the Uganda shapefile

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
 
#%% SAVE the selected glofas stations .nc files to .csv in a separated folder (every 3 days mean ensemble)

for station in stations_list:
    df_y=pd.DataFrame(columns=['time', 'dis'])
    flow=di[station]['dis'].median(dim='ensemble').sel(step=1).drop(['step']) # median of esemble variables
    df_y['time']=flow['time'].values         
    df_y['dis']=pd.Series(flow.values.flatten())  
    df_y=df_y.set_index('time')
   
    df_y.to_csv(('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/glofas/GLOFAS_data_for_%s.csv' %station))

#%% Extracting Station information with lat and lon in a csv file and computing Glofas quantiles per station
# Q90 correspond to a return period of (1/0.1) = 10 years    
# Q95 correspond to a return period of (1/0.05) = 20 years  
# Q98 correspond to a return period of (1/0.02) = 50 years  
    
df_station=pd.DataFrame(columns=['Station', 'location', 'Lat','Lon', 'Q90', 'Q95', 'Q98'])

for i in range(len(location_list)):
    station= stations_list[i]  
    df_station.loc[i,'Station']= stations_list[i]
    df_station.loc[i,'location']= location_list[i]
    df_station.loc[i,'Lon']= Lon_list[i]
    df_station.loc[i,'Lat']= Lat_list[i]
    # Add GLOFAS quantile thresholds to the df_station table :
    try:                                
        #using memory selected netcdf dataset 
        #df_station.loc[i,'Q90']= di[station].dis.quantile(0.9).values
        #df_station.loc[i,'Q95']= di[station].dis.quantile(0.95).values
        #df_station.loc[i,'Q98']= di[station].dis.quantile(0.98).values
        #using created .csv files daily mean
        gl_station=pd.read_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/glofas/GLOFAS_data_for_%s.csv' %station)
        df_station.loc[i,'Q90']= gl_station.dis.quantile(0.9)
        df_station.loc[i,'Q95']= gl_station.dis.quantile(0.95)
        df_station.loc[i,'Q98']= gl_station.dis.quantile(0.98)
    except:
        continue
    
df_station.to_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/shapes/uga_glofas_stations/uga_glofas_station.csv')

    
#%% Open the flood impact csv file and create a dataframe

flood_events=pd.read_csv("C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/impact_data.csv", encoding='latin-1')  # load impact data
Affected_admin2=np.unique(flood_events['Area'].values)   # create a list of Area
flood_events.index=flood_events['Date'] # create a list of event dates
df_event=pd.DataFrame(flood_events)

print(flood_events.index)
print(Affected_admin2)

#%%  open the impacted_area and Glofas related stations per district files

district_glofas=pd.read_csv("C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/AFFECTED_DIST_with_glofas_ABU.csv", encoding='latin-1')  
df_dg= pd.DataFrame(district_glofas)
df_dg=df_dg.set_index('name')
 
#create plot per district only for the district having recorded impact and for the related glofas stations per district
 
for districts in Affected_admin2: # for each district of Uganda
    print('############')
    print(districts)
    df_event1=df_event[df_event['Area']==districts]
    df_event1=df_event1['flood'] 
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
  
 #%% to do : GLOFAS Analysis / POD/ FAR

    

