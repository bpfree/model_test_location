#############################
### 12. Shipping fairways ###
#############################

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
#### shipping fairways
data_dir <- "data/a_raw_data/shippinglanes"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
shipping_fairway_gpkg <- "data/b_intermediate_data/westport_shipping_fairway.gpkg"

#####################################

# inspect layers within geodatabases and geopackages
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
export_name <- "shipping_fairway"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## shipping fairway data (source: http://encdirect.noaa.gov/theme_layers/data/shipping_lanes/shippinglanes.zip)
### metadata: https://www.fisheries.noaa.gov/inport/item/39986
shipping_fairway <- sf::st_read(dsn = file.path(paste(data_dir, "shippinglanes.shp", sep ="/"))) %>%
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
westport_shipping_fairway <- shipping_fairway %>%
  # obtain only shipping fairway in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "shipping fairway" for summary
  dplyr::mutate(layer = "shipping fairway")

#####################################
#####################################

# shipping fairway hex grids
westport_shipping_fairway_hex <- westport_hex[westport_shipping_fairway, ] %>%
  # spatially join shipping fairway values to Westport hex cells
  sf::st_join(x = .,
              y = westport_shipping_fairway,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer) %>%
  # group by the index values as there are duplicates
  dplyr::group_by(index) %>%
  # summarise by index
  dplyr::summarise()

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_shipping_fairway_hex, dsn = constraints_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## shipping fairway geopackage
sf::st_write(obj = shipping_fairway, dsn = shipping_fairway_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_shipping_fairway, dsn = shipping_fairway_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
