######################################
### 24. Offshore wind energy areas ###
######################################

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
#### offshore wind energy areas
data_dir <- "data/a_raw_data/BOEM-Renewable-Energy-Geodatabase/BOEMWindLayers_4Download.gdb"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
offshore_wind_gpkg <- "data/b_intermediate_data/westport_offshore_wind.gpkg"

#####################################

# inspect layers within geopackages
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
export_name <- "offshore_wind"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## offshore wind areas (source: https://www.boem.gov/renewable-energy/boem-renewable-energy-geodatabase)
### metadata: https://www.arcgis.com/sharing/rest/content/items/709831444a234968966667d84bcc0357/info/metadata/metadata.xml?format=default&output=html
offshore_wind <- sf::st_read(dsn = data_dir,
                             layer = sf::st_layers(data_dir)[[1]][grep(pattern = "Wind_Leases",
                                                                       x = sf::st_layers(dsn = data_dir)[[1]])]) %>%
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
westport_offshore_wind <- offshore_wind %>%
  # obtain only offshore wind in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "offshore wind" for summary
  dplyr::mutate(layer = "offshore wind")

#####################################
#####################################

# offshore wind hex grids
westport_offshore_wind_hex <- westport_hex[westport_offshore_wind, ] %>%
  # spatially join offshore wind values to Westport hex cells
  sf::st_join(x = .,
              y = westport_offshore_wind,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_offshore_wind_hex, dsn = constraints_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_offshore_wind_hex, dsn = study_region_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

## federal waters geopackage
sf::st_write(obj = offshore_wind, dsn = offshore_wind_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_offshore_wind_hex, dsn = offshore_wind_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
