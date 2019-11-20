# -*- coding: utf-8 -*-
"""
Created on Wed Nov 20 10:54:39 2019

@author: ATeklesadik
"""
# -*- coding: utf-8 -*-
"""
Created on Wed Nov 20 10:54:39 2019

@author: ATeklesadik
"""
import geopandas as gpd
import fiona
import descartes
from osgeo import ogr
from shapely.geometry import Polygon
import numpy as np

################################# 
def add_to_list(items,list_):
    for elments in items:
        if elments not in list_:
            list_.append(elments)
    return list_

     

def catchment_extractor(sample_admin):
    datalist={}
    basin = gpd.read_file('C:/documents/General_data/Basins/hydrosheds/African_basins/hybas_lake_af_lev12_v1c.shp')
    basin_check2 = gpd.overlay(basin,sample_admin, how='identity')
    basin_check = basin_check2[basin_check2['Pcode'].isin(sample_admin['Pcode'].values)]
    basin_check = basin_check.sort_values(by=['UP_AREA'],ascending=False)
    basin_check.drop_duplicates(subset ="HYBAS_ID", keep = 'first', inplace = True) 
    basin_check1 = basin_check.iloc[:1]
    print(basin_check1)
    for j in basin_check1['HYBAS_ID'].values:
        list_con=[]
        list_con.append(j)
        item = np.unique(basin[basin['NEXT_DOWN'] == j]['HYBAS_ID'].values)
        list_con=add_to_list(item,list_con)
        ii=0
        checker={}
        if len(item) >0:
            while True: 
                ii=ii+1
                if len(item) >0:
                    for i in item:
                        itm2 = basin[basin['NEXT_DOWN'] == i]['HYBAS_ID'].values
                        list_con=add_to_list(itm2,list_con)
                    item=list_con 
                    checker[ii]=len(list_con)
                    if (len(checker) >4) and (checker[ii]==checker[ii-1]):
                        break
        cachment= basin[basin['HYBAS_ID'].isin(list_con)] 
        datalist[j] = cachment            
    return(datalist)
    
################################# run the code for sample admin 

eth_admin3 = gpd.read_file('C:/documents/ethiopia/admin3/admin3.shp')
rivers =gpd.read_file('C:/documents/General_data/Basins/hydrosheds/African_rivers/af_riv_15s.shp')

rivers = gpd.overlay(eth_admin3, rivers, how='intersection')
sample_admin = eth_admin3[0:1]
           
event_tc=catchment_extractor(sample_admin)

################# plot to see the result 
for key,valu in event_tc.items():
    print(key)
    valu.plot()
