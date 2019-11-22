### Notes
##
Data for each country is located in raw_data folder



### UGANDA data folder directory layout

    .
      ├── Output/Ugandachirps_anomalies        # folder for rainfall annomaly based on chirps data 
      ├── processed_data/uganda       # folder for rainfall annomaly based on chirps data 
      ├── raw_data      # folder for rainfall annomaly based on chirps data 
        ├── UGANDA      # folder for rainfall annomaly based on chirps data       
          ├── chirps_anomalies        # folder for rainfall annomaly based on chirps data 
          ├── chirps_dayaverages      # Folder for daily rainfall averages
          ├── Chirps_tiffs            # Chirps tiff format 
          ├── glofs                   # CSV files for GLOFAS data
           └── AFFECTED_DIST_with_glofas.csv   # Reorganized repo to easily add other countries in the future
           └── CRA Oeganda.xlsx
           └── DI_uga.csv
           .
           .
      ├── scripts      # folder for rainfall annomaly based on chirps data 
           └── catchment_extractor.py   # for each admin location this script will extract catchment area
           └── create_anomaly_data.R    # script to calculate rainfall annomaly whichis one variable in the trigger model
           └── create_rain_data.R    # after downloading rainfall use this script to extract rainfall per catchment 
           └── download_rain_data.py    # download rainfall data
           └── glofas_research.R    # a script which will explore if GLOFAS flow data from a station capture a flood impact event 
           └── make_flood_plots.R    # this script plot impact data and GLOFAS flow data
           └── prepare_glofas_data.R    # based on glofas station per district(for each district you have to create a csv file which                                        associate a potential glofas station ) this script then make a datamatrix by combining all the sation                                    district information
           ├── shiny_uganda_data_explorer      # folder for an app which is used for rainfall data visualization          
      
      ├── shapes      # folder for radmin boundaries 
        .
        .
      └── region_model.R        # folder for uganda admin 
      └── settings.R            # a script which pass information on folder structure, projections etc... to the main code
      └── region_model.R        # Main code for the trigger model. This code will use all the other codes in the script folder 
      
To run catchment extractor script addtional data is needed - this can be found in the following link https://rodekruis.sharepoint.com/:f:/s/510-CRAVK-510/EhG4P2uRQRZKjZiJlo7YMYwBs5sqYxzcHmElbF4GtCGF6Q?e=g2mdMV
