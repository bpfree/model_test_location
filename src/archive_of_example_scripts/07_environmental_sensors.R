##########################################
### 7. Environmental buoys and sensors ###
##########################################

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
#### environmental sensors and buoys
data_dir <- "data/a_raw_data/PhysicalOceanography/PhysicalOceanography/PhysicalOceanography.gdb"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
environmental_sensor_gpkg <- "data/b_intermediate_data/westport_environmental_sensor.gpkg"

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

## setback distance (in meters)
setback <- 500

## layer names
export_name <- "environmental_sensor"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## environmental sensors and buoys data (source: https://www.northeastoceandata.org/files/metadata/Themes/PhysicalOceanography.zip)
### metadata: https://www.northeastoceandata.org/files/metadata/Themes/PhysicalOceanography/NERACOOSBuoys.htm
envir_sense <- sf::st_read(dsn = data_dir,
                           # NERACOOS buoys are the first dataset
                           layer = sf::st_layers(data_dir)[[1]][1]) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs) %>%
  # apply 500-meter setback
  sf::st_buffer(x = ., dist = setback)

#####################################

## study region
westport_region <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area", sep = "_"))

## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

#####################################
#####################################

# limit data to study region
westport_envir_sense <- envir_sense %>%
  # obtain only environmental sensors and buoys in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "environmental sensors and buoys" for summary
  dplyr::mutate(layer = "environmental sensors and buoys")

#####################################
#####################################

# environmental sensor and buoys hex grids
westport_envir_sense_hex <- westport_hex[westport_envir_sense, ] %>%
  # spatially join environmental sensors and buoys values to Westport hex cells
  sf::st_join(x = .,
              y = westport_envir_sense,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_envir_sense_hex, dsn = constraints_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## environmental sensor and buoys area geopackage
sf::st_write(obj = envir_sense, dsn = environmental_sensor_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_envir_sense, dsn = environmental_sensor_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
