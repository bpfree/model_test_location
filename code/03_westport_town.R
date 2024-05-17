############################
### 3. Westport boundary ###
############################

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
#### Massachusetts town survey
data_dir <- "data/a_raw_data/townssurvey_gdb/townssurvey.gdb"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### constraints
constraints_gpkg <- "data/c_submodel_data/constraints.gpkg"

#### intermediate directories
westport_town_gpkg <- "data/b_intermediate_data/westport_town.gpkg"

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

## setback distance (in meters)
setback <- 32186.9 # 20 miles = 32186.9 meters

## layer names
export_name <- "town"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# load data
## Massachusetts town data (source: https://s3.us-east-1.amazonaws.com/download.massgis.digital.mass.gov/gdbs/townssurvey_gdb.zip)
### metadata: https://www.mass.gov/info-details/massgis-data-municipalities
westport_town <- sf::st_read(dsn = data_dir,
                             layer = sf::st_layers(data_dir)[[1]][3]) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs) %>%
  # get Westport
  dplyr::filter(TOWN == "WESTPORT") %>%
  # group by "town" to have all features group to only "Westport"
  dplyr::group_by(TOWN) %>%
  # summarise by grouping to have single feature
  dplyr::summarise() %>%
  sf::st_buffer(dist = setback)

plot(westport_town)

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_town, dsn = constraints_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_town, dsn = study_region_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

## federal waters geopackage
sf::st_write(obj = westport_town, dsn = westport_town_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
