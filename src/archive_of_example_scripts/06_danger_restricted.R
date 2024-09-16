############################################
### 6. Danger zones and restricted areas ###
############################################

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
#### danger zones and restricted areas
data_dir <- "data/a_raw_data/DangerZoneRestrictedArea/DangerZoneRestrictedArea.gpkg"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
danger_gpkg <- "data/b_intermediate_data/westport_danger_restricted_zones.gpkg"

#####################################

# inspect layers within geodatabases and geopackages
sf::st_layers(dsn = data_dir,
              do_count = T)

sf::st_layers(dsn = study_region_gpkg,
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
export_name <- "danger_zones_restricted_areas"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## danger zones and restricted areas data (source: https://marinecadastre.gov/downloads/data/mc/DangerZoneRestrictedArea.zip)
### metadata: https://www.fisheries.noaa.gov/inport/item/48876
danger_zones <- sf::st_read(dsn = data_dir,
                            layer = sf::st_layers(data_dir)[[1]][1]) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs)

#####################################

## study region
westport_region <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area", sep = "_"))

## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

#####################################
#####################################

# limit data to study region
westport_danger_zones <- danger_zones %>%
  # obtain only danger zones and restricted areas in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "danger zones and restricted areas" for summary
  dplyr::mutate(layer = "danger zones and restricted areas")

#####################################
#####################################

# danger zone and restricted area hex grids
westport_danger_hex <- westport_hex[westport_danger_zones, ] %>%
  # spatially join danger zones and restricted areas values to Westport hex cells
  sf::st_join(x = .,
              y = westport_danger_zones,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_danger_hex, dsn = constraints_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## danger zone and restricted area geopackage
sf::st_write(obj = danger_zones, dsn = danger_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_danger_zones, dsn = danger_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
