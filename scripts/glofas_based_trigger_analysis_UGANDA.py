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
        #aa=admin_shp['geometry'].intersects(point)
        stations_list.append(stid)
        location_list.append(sna)
        Lon_list.append(Lon)
        Lat_list.append(Lat)
        di[stid]=data 
    data.close()
 #%% Extracting Station information with lat and lon in a csv file

df_station=pd.DataFrame(columns=['Station', 'location', 'Lat','Lon'])

for i in range(len(location_list)):
    df_station.loc[i,'Station']= stations_list[i]
    df_station.loc[i,'location']= location_list[i]
    df_station.loc[i,'Lon']= Lon_list[i]
    df_station.loc[i,'Lat']= Lat_list[i]
    
df_station.to_csv('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/shapes/uga_glofas_stations/uga_glofas_station.csv')
    
#%%
# Open the flood impact csv file and create a dataframe
flood_events=pd.read_csv("C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/impact_data.csv", encoding='latin-1')  # load impact data
Affected_admin2=np.unique(flood_events['Area'].values)   # create a list of Area
flood_events.index=flood_events['Date'] # create a list of event dates
df_event=pd.DataFrame(flood_events)

print(flood_events.index)
print(Affected_admin2)

 #%% 
# open the impacted_area and Glofas related files
district_glofas=pd.read_csv("C:/CODE_510/statistical_floodimpact_uganda-Ghitub/raw_data/uganda/AFFECTED_DIST_with_glofas_ABU.csv", encoding='latin-1')  
df_districtGlofas= pd.DataFrame(district_glofas)


 #%%  
############################################################ create plot per district 
 
 
for districts in Affected_admin2:
    df_event1=df_event[df_event['Area']==districts]
    df_event1=df_event1['flood'] 
    df_y=pd.DataFrame()
    for ele in stations_list:
        flow=di[ele]['dis'].median(dim='ensemble').sel(step=1).drop(['step'])#.sel(ensemble=1,step=1) median of esemble variables
        flow_=flow.resample(time='1D').interpolate('linear')#asfreq()#.mean(dim='time')#sum()#reduce(np.sum)      
        df_y[ele]=pd.Series(flow_.values.flatten())  
        df_y['time']=flow_['time'].values
        #df_y.set_index('time', inplace=True)
        #st = flow_['time'].values[0]
        #en = flow_['time'].values[-1]
    dff=normalize(df_y.drop('time',axis=1))
    dff['time']=df_y['time']
    df = dff.melt('time', var_name='Stations',  value_name='dis')
      
    
    fig = plt.figure(figsize=(16, 12),frameon=False, dpi=400)
    ax1 = fig.add_subplot(1, 1, 1)
    #df_y.plot(ax=ax1)
    ax1.set_xlabel('Time (year)', fontsize=18)
    ax1.set_ylabel('Scale flow', fontsize=18)
    sns.lineplot(x="time", y="dis",  hue="Stations", data=df,ax=ax1)
    for index, row in df_event1.iteritems():#iterrows():
        if row==1:
            ax1.axvline(x=index, color='y', linestyle='--')  
    #ax1.text('2004-01-01',fontsize=18)
    #ax1.text('2015-01-01',.8, '(Glofas Test for Admin =%s'%districts,fontsize=18,bbox=dict(facecolor='red', alpha=0.5))
    ax1.set_title( '(Glofas Test for Admin =%s'%districts,fontsize=20,bbox=dict(facecolor='red', alpha=0.5))
    #ax1.text(.25, .25, '(Glofas Test for Admin =%s'%districts,fontsize=18,bbox=dict(facecolor='red', alpha=0.5), horizontalalignment='right', verticalalignment='bottom',  transform=ax1.transAxes)
    fig.savefig('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Glofas_Analysis/flow_impact_%s.png' %districts)
    plt.clf()
    #ax1.text(.75, .75, '(Glofas Test for Admin =%s'%districts,fontsize=18,bbox=dict(facecolor='red', alpha=0.5), horizontalalignment='right', verticalalignment='bottom',  transform=ax1.transAxes)
 #%%
print(df_event1.iteritems())
