####################################
### 14. Military operating areas ###
####################################

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
#### military operating areas
data_dir <- "data/a_raw_data/MilitaryCollection/MilitaryCollection.gpkg"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### national security
national_security_gpkg <- "data/c_submodel_data/national_security.gpkg"

#### intermediate directories
military_operating_gpkg <- "data/b_intermediate_data/westport_military_operating.gpkg"

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
export_name <- "military_operating"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## military operating area data (source: https://marinecadastre.gov/downloads/data/mc/MilitaryCollection.zip)
### metadata: https://www.fisheries.noaa.gov/inport/item/55364
military_operating <- sf::st_read(dsn = data_dir,
                                    # military operating area
                                    layer = sf::st_layers(data_dir)[[1]][2]) %>%
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
westport_military_operating <- military_operating %>%
  # obtain only military operating area in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "military operating area" for summary
  dplyr::mutate(layer = "military operating area")

#####################################
#####################################

# military operating area hex grids
westport_military_operating_hex <- westport_hex[westport_military_operating, ] %>%
  # spatially join military operating area values to Westport hex cells
  sf::st_join(x = .,
              y = westport_military_operating,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_military_operating_hex, dsn = national_security_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## military operating area geopackage
sf::st_write(obj = military_operating, dsn = military_operating_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_military_operating, dsn = military_operating_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
