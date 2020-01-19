import xarray as xr
import os
import pandas as pd
import cdsapi
import zipfile
import plac
import shutil

def download_and_merge(year_start=2000, year_end=2019):
    """"
    download global glofas data and merge it per year
    """

    c = cdsapi.Client()
    glofas_year_dir = 'data_all_'+str(year_start)+'_'+str(year_end)
    # os.mkdir(glofas_year_dir)  # create folder for year data merge

    # loop over years and months
    for year in range(year_start, year_end+1):

        for month in range(1, 13):

            if os.path.isfile(glofas_year_dir + '/' + str(year) + '_' + str(month) + '_merged.nc'):
                continue
            print(str(year) + '_' + str(month))

            # download zip file
            try:
                c.retrieve(
                    'cems-glofas-historical',
                    {
                        'format': 'zip',
                        'variable': 'River discharge',
                        'dataset': 'Consolidated reanalysis',
                        'version': '2.1',
                        'year': str(year),
                        'month': str("{:02d}".format(month)),
                        'day': [
                            '01', '02', '03',
                            '04', '05', '06',
                            '07', '08', '09',
                            '10', '11', '12',
                            '13', '14', '15',
                            '16', '17', '18',
                            '19', '20', '21',
                            '22', '23', '24',
                            '25', '26', '27',
                            '28', '29', '30',
                            '31',
                        ],
                    },
                    'download.zip')
            except:
                continue

            # extract to new directory
            glofas_month_dir = str(year) + '_' + str(month)
            os.mkdir(glofas_month_dir)
            with zipfile.ZipFile('download.zip', 'r') as zip_ref:
                zip_ref.extractall(path='./'+glofas_month_dir)

            # delete zip file
            os.remove('download.zip')

            # merge monthly data in one dataframe
            ncconcat = xr.Dataset()
            for ix, file in enumerate(os.listdir(glofas_month_dir)):
                nc = xr.open_dataset(glofas_month_dir+'/'+file)
                if ix == 0:
                    ncconcat = nc
                else:
                    ncconcat = xr.concat([ncconcat, nc], dim='time')  # to concatenate the .nc on time
                del nc

            # save new dataframe
            ncconcat.to_netcdf(glofas_year_dir+'/'+str(year)+'_'+str(month)+'_merged.nc')

            # remove monthly data to save space
            shutil.rmtree(glofas_month_dir)

if __name__ == '__main__':
    plac.call(download_and_merge)