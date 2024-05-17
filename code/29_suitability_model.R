#############################
### 29. Suitability model ###
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
#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

#### suitability geopackage
suitability_gpkg <- "data/d_suitability_data/suitability.gpkg"

## Output directories
### suitability directory
suitability_dir <- "data/d_suitability_data"
dir.create(paste0(suitability_dir, "/",
                  "overall_suitability"))

overall_suitability_dir <- "data/d_suitability_data/overall_suitability"
overall_suitability <- "data/d_suitability_data/overall_suitability/westport_overall_suitability.gpkg"

#####################################

# inspect layers within geopackage
sf::st_layers(dsn = study_region_gpkg,
              do_count = T)

sf::st_layers(dsn = suitability_gpkg,
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
export_name <- "suitability"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

## geometric mean weight
### four submodels are: national security, industry / transportation / navigation, fisheries, and natural / cultural resources
gm_wt <- 1/4

#####################################
#####################################

# load data
## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

## suitability submodels
### constraints
constraints <- sf::st_read(dsn = suitability_gpkg,
                           layer = sf::st_layers(suitability_gpkg)[[1]][grep(pattern = "constraints",
                                                                             sf::st_layers(dsn = suitability_gpkg,
                                                                                           do_count = T)[[1]])]) %>%
  # remove geometry
  sf::st_drop_geometry()

### national security
national_security <- sf::st_read(dsn = suitability_gpkg,
                                 layer = sf::st_layers(suitability_gpkg)[[1]][grep(pattern = "security",
                                                                                   sf::st_layers(dsn = suitability_gpkg,
                                                                                                 do_count = T)[[1]])]) %>%
  # remove geometry
  sf::st_drop_geometry()

### industry, transportation, and navigation
industry <- sf::st_read(dsn = suitability_gpkg,
                        layer = sf::st_layers(suitability_gpkg)[[1]][grep(pattern = "industry",
                                                                          sf::st_layers(dsn = suitability_gpkg,
                                                                                        do_count = T)[[1]])]) %>%
  # remove geometry
  sf::st_drop_geometry()

### fisheries
fisheries <- sf::st_read(dsn = suitability_gpkg,
                         layer = sf::st_layers(suitability_gpkg)[[1]][grep(pattern = "fisheries",
                                                                           sf::st_layers(dsn = suitability_gpkg,
                                                                                         do_count = T)[[1]])]) %>%
  # remove geometry
  sf::st_drop_geometry()

### natural and cultural resources
natural_cultural <- sf::st_read(dsn = suitability_gpkg,
                                 layer = sf::st_layers(suitability_gpkg)[[1]][grep(pattern = "cultural",
                                                                                   sf::st_layers(dsn = suitability_gpkg,
                                                                                                 do_count = T)[[1]])]) %>%
  # remove geometry
  sf::st_drop_geometry()

#####################################
#####################################

suitability_model <- westport_hex %>%
  # join the constraints areas by index field to the full Westport hex grid
  dplyr::left_join(x = .,
                   y = constraints,
                   by = "index") %>%
  # join the national security areas by index field to the full Westport hex grid
  dplyr::left_join(x = .,
                   y = national_security,
                   by = "index") %>%
  # join the industry, transportation, and navigation areas by index field to the full Westport hex grid
  dplyr::left_join(x = .,
                   y = industry,
                   by = "index") %>%
  # join the fisheries areas by index field to the full Westport hex grid
  dplyr::left_join(x = .,
                   y = fisheries,
                   by = "index") %>%
  # join the natural and cultural resources areas by index field to the full Westport hex grid
  dplyr::left_join(x = .,
                   y = natural_cultural,
                   by = "index")

#####################################

model_areas <- suitability_model %>%
  # remove any areas that are constraints -- thus get areas that are NA
  dplyr::filter(is.na(constraints)) %>%
  
  # calculate the geometric mean
  ## geometric mean = nth root of the product of the variable values
  dplyr::mutate(model_geom_mean = (ns_geom_mean ^ gm_wt) * (itn_geom_mean ^ gm_wt) * (nc_geom_mean ^ gm_wt)) %>%
  
  # select desired fields
  dplyr::select(index,
                # constraints
                uxo_loc_value, danger_value, environmental_value, #disposal_value,
                navigation_value, wreck_value, shipping_value,
                # national security
                uxo_area_value, military_value,
                # industry, transportation, and navigation
                ais_max,
                # fisheries
                vms_all_max, vms_kt_max, vtr_max, lps_max,
                # natural and cultural resources
                cpr_max,
                # submodel geometric values
                constraints, ns_geom_mean, itn_geom_mean, fish_geom_mean, nc_geom_mean,
                # model geometric value
                model_geom_mean)

dim(model_areas)[1] - dim(model_areas[!is.na(model_areas$constraints), ])[1]
dim(model_areas)[1]

#####################################

# export data
## overall suitability
sf::st_write(obj = model_areas, dsn = suitability_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

## submodels
saveRDS(object = constraints, file = paste(overall_suitability_dir, paste(region, "hex", export_name, "constraints.rds", sep = "_"), sep = "/"))
saveRDS(object = national_security, file = paste(overall_suitability_dir, paste(region, "hex", export_name, "national_security.rds", sep = "_"), sep = "/"))
saveRDS(object = industry, file = paste(overall_suitability_dir, paste(region, "hex", export_name, "industry.rds", sep = "_"), sep = "/"))
saveRDS(object = fisheries, file = paste(overall_suitability_dir, paste(region, "hex", export_name, "fisheries.rds", sep = "_"), sep = "/"))
saveRDS(object = natural_cultural, file = paste(overall_suitability_dir, paste(region, "hex", export_name, "natural_cultural.rds", sep = "_"), sep = "/"))

## model
sf::st_write(obj = model_areas, dsn = overall_suitability, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
