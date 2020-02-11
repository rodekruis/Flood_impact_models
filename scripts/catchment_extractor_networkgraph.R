library(tidyverse)
library(sf)
library(igraph)
source("settings.R")
settings <- catchment_extraction_settings

# extracts all upstream catchments for an areea
extract_catchments <- function(admin_shape, basins_africa, basin_graph) {
  direct_basins <- st_intersection(admin_shape, basins_africa) %>% pull(HYBAS_ID)
  all_basins_of_admin <- c()
  
  for (basin_id in direct_basins) {
    upstream_basins <- subcomponent(basin_graph, as.character(basin_id), mode='in')
    all_basins_of_admin <- union(all_basins_of_admin, as.numeric(names(upstream_basins)))
  }
  return(all_basins_of_admin)
}

#######################################################################################################################
#### Load in relevant shapes
#######################################################################################################################

# Read in basins and rivers for all of africa
basins_africa <- st_read(dsn=settings$basins_folder, layer=settings$basins_layer)
rivers <- st_read(dsn=settings$river_folder, layer=settings$river_layer)

# Read in the admin shapes of interest, keep their identifier and filter out invalid geometries
admin_shapes <- st_read(dsn=settings$admin_folder, layer=settings$admin_layer)
admin_shapes <- admin_shapes %>%
  dplyr::select(!!sym(settings$admin_identifier), geometry) %>%
  filter(st_is_valid(geometry))

admin_shapes <- st_transform(admin_shapes, st_crs(basins_africa))

#######################################################################################################################
#### Create directed network graph
#######################################################################################################################
# Remove rows that have no upstream area (and thus no edge)
basin_edges <- basins_africa %>%
  dplyr::select(HYBAS_ID, NEXT_DOWN) %>%
  filter(NEXT_DOWN != 0)

st_geometry(basin_edges) <- NULL

# Get vertices from original basins file to also include catchments with no upstream catchments as vertices
basin_graph <- graph_from_data_frame(basin_edges, vertices = as.vector(na.omit(union(basins_africa$HYBAS_ID, basins_africa$NEXT_DOWN))))

#######################################################################################################################
#### Get all upstream catchments for all admin polygons and save the result
#######################################################################################################################
result = list()
for (i in 1:nrow(admin_shapes)) {
  print(paste0("Extracting for admin ", i, " of ", nrow(admin_shapes)))
  # Collect input
  current_admin <- admin_shapes[i, ]
  current_admin_id <- current_admin[[settings$admin_identifier]]
  
  # The actual catchment extraction using the network graph
  all_basins_of_admin <- extract_catchments(current_admin, basins_africa, basin_graph)
  
  # This check is necessary for shapes that are completely outside of the basin shapes (happened once for ethiophia)
  if (!is.null(all_basins_of_admin)) {
    # Combine the resulting catchment into one shape and save
    result[[as.character(current_admin_id)]] <- basins_africa %>%
      filter(HYBAS_ID %in% all_basins_of_admin) %>%
      filter(st_is_valid(geometry)) %>%
      st_union() %>% as_Spatial()
    
    # Set the id of the catchment shape to the admin id
    slot(slot(result[[as.character(current_admin_id)]], "polygons")[[1]], "ID") <- as.character(current_admin_id) 
  }
}

# Combine the catchments for each admin shape into one spatialdataframe
result_polygons <- SpatialPolygons(lapply(result, function(x) slot(x, "polygons")[[1]]))
admin_ids <- data.frame(admin_id = sapply(slot(result_polygons, "polygons"), function(x) slot(x, "ID")))
spatial_df <- st_as_sf(SpatialPolygonsDataFrame(result_polygons, admin_ids))
# here is a code to visualize adminboundary,extracted basin and river network (it helps to understand the code)
                                          
# library(tmap)
#rivers_<- st_crop(rivers, st_bbox(admin_shapes))
#tmap_mode(mode = "view")
#tm_shape(admin_shapes[4,]) + tm_polygons(col =NA,colorNA=NULL,border.col = "black",lwd = 0.5,lyt='dotted')+
#  tm_shape(spatial_df [4,]) +
#  tm_polygons(col =NA,colorNA=NULL,alpha=0.3,border.col = "red",lwd = 0.1,lyt='dotted') +
# tm_shape(rivers_) +
# tm_lines(col ='blue',scale=2,lwd = 0.1)
                                          
                                          
# Save to shapefile (and create output folder if it does not exist)
dir.create(settings$output_folder, recursive=TRUE, showWarnings = FALSE)
st_write(spatial_df, paste0(settings$output_folder, "/", settings$output_filename), update=TRUE)
