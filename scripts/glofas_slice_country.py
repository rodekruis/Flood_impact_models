import xarray as xr
import os
import pandas as pd
import cdsapi
import zipfile
import plac
import shutil
from country_bounding_boxes import country_subunits_containing_point, country_subunits_by_iso_code

def slice_country(country_iso_code='ML'):
    """"
    load global glofas data, select one country and save it in a separate file
    """

    # load country bounding box (see https://github.com/graydon/country-bounding-boxes)
    bbox = [c.bbox for c in country_subunits_by_iso_code(country_iso_code)][0]
    longmin = bbox[0]
    longmax = bbox[2]
    latmin = bbox[3]
    latmax = bbox[1]
    print(longmin, longmax, latmin, latmax)

    data_dir = 'data_all_2000_2019' # global glofas data directory
    ncconcat = xr.Dataset() # initialize final country file

    # loop over all global glofas data
    for ix, file in enumerate(os.listdir(data_dir)):
        nc = xr.open_dataset(data_dir + '/' + file)
        # select country
        nc_c = nc.sel(lon=slice(longmin, longmax), lat=slice(latmin, latmax))

        # if first iteration, copy to new country file, otherwise concatenate to existing one
        if ix == 0:
            print(nc)
            ncconcat = nc_c
        else:
            ncconcat = xr.concat([ncconcat, nc_c], dim='time')
        del nc, nc_c

    # save new dataframe
    print(ncconcat)
    ncconcat.to_netcdf('data_'+country_iso_code+'.nc')

if __name__ == '__main__':
    plac.call(slice_country)