crs1 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

country_settings <- list(
  "uganda" = list(
    "boundary_shape_path" = "shapes/uga_admbnda_adm1/uga_admbnda_adm1_UBOS_v2.shp",
    "boundary_layer_name" = "uga_admbnda_adm1_UBOS_v2",
    "catchment_id_column" = "pcode"
  ),
  "kenya" = list(
    "boundary_shape_path" = "shapes/kenya_adm1/KEN_adm1_mapshaper_corrected.shp",
    "boundary_layer_name" = "KEN_adm1_mapshaper_corrected",
    "catchment_shape_path" = "shapes/kenya_catchment/Busa_catchment.shp",
    "catchment_layer_name" = "Busa_catchment",
    "catchment_id_column" = "HYBAS_ID"
  ) 
)

catchment_extraction_settings <- list(
  "basins_folder" = "shapes/all_basins_and_rivers",
  "basins_layer" = "hybas_lake_af_lev12_v1c",
  "river_folder" = "shapes/all_basins_and_rivers",
  "river_layer" =  "af_riv_15s",
  "admin_folder" = "shapes/ethiopia_admin",
  "admin_layer" = "ETH_adm1_mapshaper",
  "admin_identifier" = "REG_Pcode",
  "output_folder" = "shapes/catchments/ethiopia_admin1",
  "output_filename" = "ethiopia_admin1_catchments.shp"
)
