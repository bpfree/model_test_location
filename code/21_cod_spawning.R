#########################################
### 21. Cod spawning protection areas ###
#########################################

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
#### cod spawning protection areas
data_dir <- "data/a_raw_data/cod_spawning_protection_areas/GOM_Spawning_Groundfish_Closures"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### fisheries
fisheries_gpkg <- "data/c_submodel_data/fisheries.gpkg"

#### intermediate directories
cod_spawning_gpkg <- "data/b_intermediate_data/westport_cod_spawning.gpkg"

#####################################

# inspect layers within geopackage
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
export_name <- "cod_spawning"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## cod spawning protection areas data (source: https://media.fisheries.noaa.gov/2020-04/gom-spawning-groundfish-closures-20180409-noaa-garfo.zip)
### metadata: https://media.fisheries.noaa.gov/dam-migration/gom-spawning-groundfish-closures-metadata-noaa-fisheries_.pdf
cod_spawning <- sf::st_read(dsn = data_dir,
                        # cod spawning protection areas
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
westport_cod_spawning <- cod_spawning %>%
  # obtain only cod spawning protection areas in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "cod spawning protection areas" for summary
  dplyr::mutate(layer = "cod spawning protection areas")

#####################################
#####################################

# cod spawning protection areas hex grids
westport_cod_spawning_hex <- westport_hex[westport_cod_spawning, ] %>%
  # spatially join cod spawning protection areas values to Westport hex cells
  sf::st_join(x = .,
              y = westport_cod_spawning,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_cod_spawning_hex, dsn = fisheries_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## cod spawning protection areas geopackage
sf::st_write(obj = cod_spawning, dsn = cod_spawning_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_cod_spawning, dsn = cod_spawning_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
