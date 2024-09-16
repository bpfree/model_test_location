######################################
### 25. National security submodel ###
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
#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

#### national security
submodel_gpkg <- "data/c_submodel_data/national_security.gpkg"

### national security directory
suitability_dir <- "data/d_suitability_data"
dir.create(paste0(suitability_dir, "/",
                  "national_security_suitability"))

national_security_dir <- "data/d_suitability_data/national_security_suitability"
national_security_gpkg <- "data/d_suitability_data/national_security_suitability/westport_national_security_suitability.gpkg"

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
export_name <- "national_security"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

## geometric mean weight
gm_wt <- 1/2

#####################################
#####################################

# load data
## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

## constraints
### unexploded ordnance areas
westport_hex_unexploded_areas <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "uxo_area", date, sep = "_")) %>%
  dplyr::mutate(uxo_area_value = 0.5) %>%
  sf::st_drop_geometry()

### military operating areas
westport_hex_military_operating <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "military_operating", date, sep = "_")) %>%
  dplyr::mutate(military_value = 1) %>%
  sf::st_drop_geometry()

#####################################
#####################################

# Create Westport national security submodel
westport_hex_national_security <- westport_hex %>%
  dplyr::left_join(x = .,
                   y = westport_hex_unexploded_areas,
                   by = "index") %>%
  dplyr::left_join(x = .,
                   y = westport_hex_military_operating,
                   by = "index") %>%
  dplyr::select(index,
                contains("value")) %>%
  
  # add value of 1 for datasets when hex cell has value of NA
  ## for hex cells not impacted by a particular dataset, that cell gets a value of 1
  ### this indicates  suitability with wind energy development
  dplyr::mutate(across(2:3, ~replace(x = .,
                                     list = is.na(.),
                                     # replacement values
                                     values = 1))) %>%
  
  ## geometric mean = nth root of the product of the variable values
  dplyr::mutate(ns_geom_mean = (uxo_area_value ^ gm_wt) * (military_value ^ gm_wt)) %>%
  
  # relocate the industry and operations geometric mean field
  dplyr::relocate(ns_geom_mean,
                  .after = military_value)

### ***Warning: there are duplicates of the index
duplicates_verify <- westport_hex_national_security %>%
  # create frequency field based on index
  dplyr::add_count(index) %>%
  # see which ones are duplicates
  dplyr::filter(n>1) %>%
  # show distinct options
  dplyr::distinct()

#####################################
#####################################

# Export data
## Suitability
sf::st_write(obj = westport_hex_national_security, dsn = suitability_gpkg, layer = paste(region, export_name, "suitability", sep = "_"), append = F)

## Constraints
saveRDS(obj = westport_hex_military_operating, file = paste(national_security_dir, paste(region, "hex_national_security_military_operating.rds", sep = "_"), sep = "/"))
saveRDS(obj = westport_hex_unexploded_areas, file = paste(national_security_dir, paste(region, "hex_national_security_unexploded_areas.rds", sep = "_"), sep = "/"))

sf::st_write(obj = westport_hex_national_security, dsn = national_security_gpkg, layer = paste(region, "hex", export_name, "suitability", sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
