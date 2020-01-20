# -*- coding: utf-8 -*-
"""
Created on Sat Jan 18 11:12:23 2020

@author: ABucherie
"""
#%%
# setting up your environment
import xarray as xr
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np
import os
from os import listdir
from os.path import isfile, join
import geopandas as gpd
from shapely.geometry import Point
from osgeo import ogr
import xshape
import rasterio
from rasterstats import zonal_stats
import fiona
from mpl_toolkits.axes_grid1 import make_axes_locatable

#%% 
# sources
model_performance = 'C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Performance_scores/uga_glofas_performance_score.csv'
district_uganda = 'C:/CODE_510/statistical_floodimpact_uganda-Ghitub/shapes/uga_admbnda_adm1/uga_admbnda_adm1_UBOS_v2.shp'

#%% 
# Open the district admin 1 sapefile
district= gpd.read_file(district_uganda)
#open the csv file with performance results of the model
model_perf =pd.read_csv(model_performance)

# find the best station to use per district based on the lowest FAR values
best= model_perf.groupby(['district', 'quantile'])['far'].transform(min)==model_perf['far']
model_perf_best= model_perf[best]

# lower case the district column in both file and merge
district['ADM1_EN' ]= district['ADM1_EN'].str.lower()
model_perf_best['district']= model_perf_best['district'].str.lower()

merged_perf= district.set_index('ADM1_EN').join(model_perf_best.set_index('district')) 
merged_perf.to_file('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Performance_scores/perf_uga_v111.shp')

#%%  create a figure with the number of flood event recorded per district
fig, ax=plt.subplots(1,figsize=(10,10))
divider = make_axes_locatable(ax)
cax = divider.append_axes("right", size="5%", pad=0.2)

merged_perf.plot(ax=ax, color='lightgrey', edgecolor='grey')
ax.set_title('Number of recorded flood event per district', fontsize= 14)
cmap = cm.get_cmap('jet', 10)
#cmap = cm.get_cmap('gist_ncar_r', 10)

perfdrop= merged_perf.dropna(subset=['nb_event'])
perfdrop.plot(ax=ax,column='nb_event', legend= True,vmin=1,vmax=10, cmap=cmap, cax=cax)

fig.savefig('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Performance_scores/Nb_event_district.png')

#%% 
#choose the quantile to plot 
#perf_quantile= merged_perf[merged_perf['quantile']== 'Q90_pred']

quantiles = ['Q90_pred', 'Q95_pred', 'Q98_pred']

for quantile in quantiles:
    
    perf_quantile= merged_perf[merged_perf['quantile']== quantile]
    
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16,16))
    #title("Title", line = -2)
    fig.suptitle('Performance results of model v1.1.1 in Uganda (%s Glofas)'%quantile,fontsize= 22,fontweight= 'bold', x=0.5, y=0.94)   
    divider_ax1 = make_axes_locatable(ax1)
    divider_ax2 = make_axes_locatable(ax2)
    divider_ax3 = make_axes_locatable(ax3)
    divider_ax4 = make_axes_locatable(ax4)
    cax1 = divider_ax1.append_axes("right", size="5%", pad=0.2)
    cax2 = divider_ax2.append_axes("right", size="5%", pad=0.2)
    cax3 = divider_ax3.append_axes("right", size="5%", pad=0.2)
    cax4 = divider_ax4.append_axes("right", size="5%", pad=0.2)
    
    ax1.set_title('False Alarm Ratio (FAR)', fontsize= 16)
    merged_perf.plot(ax=ax1, color='lightgrey', edgecolor='grey')
    perf_quantile.plot(ax=ax1,column='far', legend= True, cmap='coolwarm', cax=cax1)
    
    ax2.set_title('Proability of Detection (POD)', fontsize= 16)
    merged_perf.plot(ax=ax2, color='lightgrey', edgecolor='grey')
    perf_quantile.plot(ax=ax2,column='pod', legend= True, cmap='coolwarm_r', cax=cax2)
    
    ax3.set_title('Proability of False Detection (POFD)', fontsize= 16)
    merged_perf.plot(ax=ax3, color='lightgrey', edgecolor='grey')
    perf_quantile.plot(ax=ax3,column='pofd', legend= True, cmap='coolwarm', cax=cax3)
    
    ax4.set_title('Critical Success Index (CSI)', fontsize= 16)
    merged_perf.plot(ax=ax4, color='lightgrey', edgecolor='grey')
    perf_quantile.plot(ax=ax4,column='pod', legend= True, cmap='coolwarm_r', cax=cax4)
    

    fig.savefig('C:/CODE_510/statistical_floodimpact_uganda-Ghitub/output/uganda/Performance_scores/Uganda_v111_%s.png' %quantile)


#%% try multiplot 
merged_perf.plot(ax=ax, color='lightgrey', edgecolor='grey')

ax.set_title('FAR results of model v1.1.1 in Uganda (Glofas only)', fontsize= 12)
perfdrop= merged_perf90.dropna(subset=['far'])
perfdrop.plot(ax=ax,column='far', legend= True, cmap='coolwarm', cax=cax)





