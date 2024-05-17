##############################################
### 5. Munitions and explosives of concern ###
##############################################

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
#### munitions and explosives of concern
mec_gpkg <- "data/a_raw_data/MunitionsExplosivesConcern/MunitionsExplosivesConcern.gpkg"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
munitions_gpkg <- "data/b_intermediate_data/westport_munitions.gpkg"

#####################################

# inspect layers within geodatabases and geopackages
sf::st_layers(dsn = mec_gpkg,
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
export_mec <- "munitions_explosives"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## munitions and explosives of concern data (source: https://marinecadastre.gov/downloads/data/mc/MunitionsExplosivesConcern.zip)
### metadata: https://www.fisheries.noaa.gov/inport/item/69013
mec <- sf::st_read(dsn = mec_gpkg, layer = "MunitionsExplosivesConcern") %>%
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
westport_mec <- mec %>%
  # obtain only munitions and explosives of concern areas in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # filter for only types of interest
  # dplyr::filter(name %in% uxo_types)
  # create field called "layer" and fill with "munitions and explosives of concern" for summary
  dplyr::mutate(layer = "munitions and explosives of concern") %>%
  dplyr::select(layer)

#####################################
#####################################

# munitions and explosives of concern hex grids
westport_mec_hex <- westport_hex[westport_mec, ] %>%
  # spatially join munitions and explosives of concern values to Westport hex cells
  sf::st_join(x = .,
              y = westport_mec,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_mec_hex, dsn = constraints_gpkg, layer = paste(region, "hex", export_mec, date, sep = "_"), append = F)

## munitions and explosives of concern geopackage
sf::st_write(obj = mec, dsn = munitions_gpkg, layer = paste(export_mec, date, sep = "_"), append = F)
sf::st_write(obj = westport_mec, dsn = munitions_gpkg, layer = paste(region, export_mec, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
