# -*- coding: utf-8 -*-
"""
Created on Sun Oct 20 20:24:03 2019

@author: ATeklesadik
"""
# import regionmask
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


def normalize(df):
    result = df.copy()
    for feature_name in df.columns:
        max_value = df[feature_name].max()
        min_value = df[feature_name].min()
        result[feature_name] = (df[feature_name] - min_value) / (max_value - min_value)
    return result
        
#########################################################
#data = xr.open_dataset('U:/backup/FBF project/zambia/glofas_simulation/glofas3R_4-977Kasaka_Kafue_Zambia_model150000_20080401_20180131.nc')
mypath='C:\\documents\\GLOFAS\\glofas'
onlyfiles = [ f for f in listdir(mypath) if isfile(join(mypath,f)) ]
admin_shp = gpd.read_file('C://documents//mali//Administrative boundaries//mli_admbnda_adm2_pop_2017.shp')  # load admin shape file for Mali
di={}
location_list=[]
stations_list=[]
for files in onlyfiles:
    Filename = os.path.join(mypath,files)
    sna=files.split('_')[5]
    data = xr.open_dataset(Filename)
    stid=files.split('_')[4]
    point =Point(data['plon'].values[0],data['plat'].values[0])
    if point.intersects(admin_shp['geometry'].unary_union): # check if Glofas station is in the polygon
        #aa=admin_shp['geometry'].intersects(point)
        stations_list.append(stid)
        location_list.append(sna)
        di[stid]=data 
    data.close()

############################################################
flood_events=pd.read_csv("C:/documents/mali/raw_data/impact_data_mali2.csv", encoding='latin-1')  # load impact data
Affected_admin2=np.unique(flood_events['Admin2'].values)
flood_events.index=flood_events['date']
df_event=pd.DataFrame(flood_events)
    
############################################################ create plot per district 
for districts in Affected_admin2:
    df_event1=df_event[df_event['Admin2']==districts]
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
    fig.savefig('C://documents//mali//output//flow_impact_%s.png' %districts)

    #ax1.text(.75, .75, '(Glofas Test for Admin =%s'%districts,fontsize=18,bbox=dict(facecolor='red', alpha=0.5), horizontalalignment='right', verticalalignment='bottom',  transform=ax1.transAxes)


