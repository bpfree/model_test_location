#########################
### 2. Federal waters ###
#########################

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
#### federal waters
data_dir <- "data/a_raw_data/CoastalZoneManagementAct/CoastalZoneManagementAct.gpkg"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
federal_waters_gpkg <- "data/b_intermediate_data/westport_federal_waters.gpkg"

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
export_name <- "federal_waters"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## federal waters data (source: https://marinecadastre.gov/downloads/data/mc/CoastalZoneManagementAct.zip)
### metadata: https://www.fisheries.noaa.gov/inport/item/53132
federal_waters <- sf::st_read(dsn = data_dir,
                              layer = sf::st_layers(data_dir)[[1]]) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs) %>%
  # get only federal waters
  dplyr::filter(CZMADomain == "federal consistency") %>%
  dplyr::group_by(CZMADomain) %>%
  dplyr::summarise()

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = federal_waters, dsn = constraints_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)
sf::st_write(obj = federal_waters, dsn = study_region_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

## federal waters geopackage
sf::st_write(obj = federal_waters, dsn = federal_waters_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
