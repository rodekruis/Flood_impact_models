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
