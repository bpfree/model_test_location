################################
### 24. Constraints submodel ###
################################

# clear environment
rm(list = ls())

# calculate start time of code (determine how long it takes to complete all code)
start <- Sys.time()

#####################################
#####################################

# load packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(docxtractr,
               dplyr,
               elsa,
               fasterize,
               fs,
               ggplot2,
               janitor,
               ncf,
               paletteer,
               pdftools,
               plyr,
               purrr,
               raster,
               RColorBrewer,
               reshape2,
               rgdal,
               rgeoda,
               rgeos,
               rmapshaper,
               rnaturalearth, # use devtools::install_github("ropenscilabs/rnaturalearth") if packages does not install properly
               sf,
               sp,
               stringr,
               terra, # is replacing the raster package
               tidyr)

#####################################
#####################################

# set directories
## define data directory (as this is an R Project, pathnames are simplified)
### input directories
#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

#### constraints
submodel_gpkg <- "data/c_submodel_data/constraints.gpkg"

### constraints directory
suitability_dir <- "data/d_suitability_data"
dir.create(paste0(suitability_dir, "/",
                  "constraints_suitability"))

constraints_dir <- "data/d_suitability_data/constraints_suitability"
constraints_gpkg <- "data/d_suitability_data/constraints_suitability/westport_constraints_suitability.gpkg"

#### suitability
suitability_gpkg <- "data/d_suitability_data/suitability.gpkg"

#####################################

# inspect layers within geopackage
sf::st_layers(dsn = study_region_gpkg,
              do_count = T)

sf::st_layers(dsn = submodel_gpkg,
              do_count = T)

#####################################
#####################################

# set parameters
## designate region name
region <- "westport"

## coordinate reference system
### EPSG:26918 is NAD83 / UTM 18N (https://epsg.io/26918)
crs <- "EPSG:26918"

## layer names
export_name <- "constraints"

## constraints value
constraints_value <- 0

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

## constraints
### offshore wind energy areas
westport_hex_offshore_wind <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "offshore_wind", date, sep = "_")) %>%
  dplyr::mutate(wind_value = 0) %>%
  sf::st_drop_geometry()

# ### unexploded ordnance locations
# westport_hex_unexploded_location <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "uxo_location", date, sep = "_")) %>%
#   dplyr::mutate(uxo_loc_value = 0) %>%
#   sf::st_drop_geometry()

### munitions and explosive concerns
westport_hex_mec <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "munitions_explosives", date, sep = "_")) %>%
  dplyr::mutate(wind_value = 0) %>%
  sf::st_drop_geometry()

### danger zones and restricted areas
westport_hex_danger_restricted <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "danger_zones_restricted_areas", date, sep = "_")) %>%
  dplyr::mutate(danger_value = 0) %>%
  sf::st_drop_geometry()

### environmental sensors and buoys
westport_hex_environmental_sensor <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "environmental_sensor", date, sep = "_")) %>%
  dplyr::mutate(environmental_value = 0) %>%
  sf::st_drop_geometry()

### ocean disposal sites
# westport_hex_ocean_disposal <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "ocean_disposal", date, sep = "_")) %>%
#   dplyr::mutate(disposal_value = 0) %>%
#   sf::st_drop_geometry()

### aids to navigation
westport_hex_aids_navigation <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "aids_navigation", date, sep = "_")) %>%
  dplyr::mutate(navigation_value = 0) %>%
  sf::st_drop_geometry()

### wrecks and obstructions
westport_hex_wreck_obstruction <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "wreck_obstruction", date, sep = "_")) %>%
  dplyr::mutate(wreck_value = 0) %>%
  sf::st_drop_geometry()

### shipping fairways
westport_hex_shipping_fairway <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "shipping_fairway", date, sep = "_")) %>%
  dplyr::mutate(shipping_value = 0) %>%
  sf::st_drop_geometry()

#####################################
#####################################

# Create Oregon constraints submodel
westport_hex_constraints <- westport_hex %>%
  dplyr::left_join(x = .,
                   y = westport_offshore_wind,
                   by = "index") %>%
  # dplyr::left_join(x = .,
  #                  y = westport_hex_unexploded_location,
  #                  by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_mec,
                   by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_danger_restricted,
                   by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_environmental_sensor,
                   by = "index") %>%
  # dplyr::left_join(x = .,
  #                  y = westport_hex_ocean_disposal,
  #                  by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_aids_navigation,
                   by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_wreck_obstruction,
                   by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_shipping_fairway,
                   by = "index") %>%
  dplyr::select(index,
                contains("value"))

### ***Warning: there are duplicates of the index
duplicates_verify <- westport_hex_constraints %>%
  # create frequency field based on index
  dplyr::add_count(index) %>%
  # see which ones are duplicates and verify that values are equal
  dplyr::filter(n>1) %>%
  # show distinct options
  dplyr::distinct()

# Keep only one result per cell
westport_constraints <- westport_hex_constraints %>%
  # group by key fields to reduce duplicates
  dplyr::group_by(index,
                  wind_value,
                  uxo_loc_value,
                  danger_value,
                  environmental_value,
                  # disposal_value,
                  navigation_value,
                  wreck_value,
                  shipping_value) %>%
  # return only distinct rows (remove duplicates)
  dplyr::distinct() %>%
  # create a field called "constraints" that populates with 0 whenever datasets equal 0
  dplyr::mutate(constraints = case_when(wind_value == 0 ~ 0,
                                        uxo_loc_value == 0 ~ 0,
                                        danger_value == 0 ~ 0,
                                        environmental_value == 0 ~ 0,
                                        # disposal_value == 0 ~ 0,
                                        navigation_value == 0 ~ 0,
                                        wreck_value == 0 ~ 0,
                                        shipping_value == 0 ~ 0)) %>%
  dplyr::relocate(constraints,
                  .after = shipping_value)

#####################################
#####################################

# Export data
## Suitability
sf::st_write(obj = westport_constraints, dsn = suitability_gpkg, layer = paste(region, export_name, "suitability", sep = "_"), append = F)

## Constraints
saveRDS(obj = westport_hex_aids_navigation, file = paste(constraints_dir, paste(region, "hex_constraint_aids_navigation.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_environmental_sensor, file = paste(constraints_dir, paste(region, "hex_constraint_environmental_sensor.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_danger_restricted, file = paste(constraints_dir, paste(region, "hex_constraint_danger_restricted.rds", sep = "_"), sep = "/"))
# saveRDS(obj = westport_hex_ocean_disposal, file = paste(constraints_dir, paste(region, "hex_constraint_ocean_disposal.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_offshore_wind, file = paste(constraints_dir, paste(region, "hex_constraint_offshore_wind.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_shipping_fairway, file = paste(constraints_dir, paste(region, "hex_constraint_shipping_fairway.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_unexploded_location, file = paste(constraints_dir, paste(region, "hex_constraint_unexploded_ordnance_location.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_wreck_obstruction, file = paste(constraints_dir, paste(region, "hex_constraint_wreck_obstruction.rds", sep = "_"), sep = "/"))

sf::st_write(obj = westport_hex_constraints, dsn = constraints_gpkg, layer = paste(region, "hex", export_name, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
