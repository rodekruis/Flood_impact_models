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
################################# run the code for sample admin 
def add_to_list(items,list_):
    for elments in items:
        if elments not in list_:
            list_.append(elments)
    return list_

def fun2(item,basin):
    for i in item:
        item2 = basin[basin['NEXT_DOWN'] == i]['HYBAS_ID'].values
    return item2
        

eth_admin3 = gpd.read_file('C:/documents/ethiopia/admin3/admin3.shp')
basin = gpd.read_file('C:/documents/General_data/Basins/hydrosheds/African_basins/hybas_lake_af_lev12_v1c.shp')
basin = gpd.overlay(basin,eth_admin3, how='identity')




rivers =gpd.read_file('C:/documents/General_data/Basins/hydrosheds/African_rivers/af_riv_15s.shp')
rivers = gpd.overlay(eth_admin3, rivers, how='intersection')

sample_admin = eth_admin3[0:1]

basin_check = gpd.overlay(basin,sample_admin,  how='intersection')
basin_check2 = gpd.overlay(basin,sample_admin, how='identity')

datalist={}
           
def catchment_extractor(sample_admin):
    #basin_check = gpd.overlay(sample_admin, basin, how='intersection')
    basin_check = basin_check2[basin_check2['Pcode'].isin(sample_admin['Pcode'].values)]
    basin_check = basin_check.sort_values(by=['UP_AREA'],ascending=False)
    basin_check1 = basin_check
    basin_check1.drop_duplicates(subset ="HYBAS_ID", keep = 'first', inplace = True) 
    basin_check1 = basin_check1.iloc[:1]
    for j in basin_check1['HYBAS_ID'].values:
        list_con=[]
        list_item=[]
        list_con.append(j)
        item = np.unique(basin[basin['NEXT_DOWN'] == j]['HYBAS_ID'].values)
        print(item)
        list_con=add_to_list(item,list_con)
        ii=100
        #if len(item) >0:
        while ii > 0: #item != []:
            ii=ii-1
            print(ii)
            l1=[]
            if len(item) >0:
                for i in item:
                    itm2 = basin[basin['NEXT_DOWN'] == i]['HYBAS_ID'].values
                    l1.append(len(itm2))
                    list_item.append(itm2.tolist())
                    list_con=add_to_list(itm2,list_con)
                #l2=max(l1)
                item=list_con #list(set(list_item)-set(item.tolist()))
        cachment= basin[basin['HYBAS_ID'].isin(list_con)] 
        datalist[j] = cachment            
    return(datalist)
event_tc=catchment_extractor(sample_admin)


for key,valu in event_tc.items():
    print(key)
    valu.plot()
