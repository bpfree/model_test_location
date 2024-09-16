#############################################################
### 26. Industry, transportation, and navigation submodel ###
#############################################################

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

#### industry, transportation, navigation
submodel_gpkg <- "data/c_submodel_data/industry_transportation_navigation.gpkg"

### industry, transportation, navigation directory
suitability_dir <- "data/d_suitability_data"
dir.create(paste0(suitability_dir, "/",
                  "industry_suitability"))

industry_dir <- "data/d_suitability_data/industry_suitability"
industry_gpkg <- "data/d_suitability_data/industry_suitability/westport_industry_suitability.gpkg"

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
export_name <- "industry"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

## geometric mean weight
gm_wt <- 1/1

#####################################
#####################################

# load data
## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

## constraints
### unexploded ordnance areas
westport_hex_ais <- sf::st_read(dsn = submodel_gpkg, layer = paste(region, "hex", "ais", date, sep = "_")) %>%
  sf::st_drop_geometry()

#####################################
#####################################

# Create Westport industry, transportation, and navigation submodel
westport_hex_industry <- westport_hex %>%
  dplyr::left_join(x = .,
                   y = westport_hex_ais,
                   by = "index") %>%
  dplyr::select(index,
                contains("max")) %>%
  
  # add value of 1 for datasets when hex cell has value of NA
  ## for hex cells not impacted by a particular dataset, that cell gets a value of 1
  ### this indicates  suitability with wind energy development
  dplyr::mutate(across(2, ~replace(x = .,
                                   list = is.na(.),
                                   # replacement values
                                   values = 1))) %>%
  
  ## geometric mean = nth root of the product of the variable values
  dplyr::mutate(itn_geom_mean = (ais_max ^ gm_wt)) %>%
  
  # relocate the industry and operations geometric mean field
  dplyr::relocate(itn_geom_mean,
                  .after = ais_max)

### ***Warning: there are duplicates of the index
duplicates_verify <- westport_hex_industry %>%
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
sf::st_write(obj = westport_hex_industry, dsn = suitability_gpkg, layer = paste(region, export_name, "suitability", sep = "_"), append = F)

## Constraints
saveRDS(obj = westport_hex_ais, file = paste(industry_dir, paste(region, "hex_industry_ais.rds", sep = "_"), sep = "/"))

sf::st_write(obj = westport_hex_industry, dsn = industry_gpkg, layer = paste(region, "hex", export_name, "suitability", sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
