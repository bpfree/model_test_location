##############################################
### 20. Large pelagic survey (2012 - 2021) ###
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
#### large pelagic survey
data_dir <- "data/a_raw_data/lps_data.gdb"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### fisheries
fisheries_gpkg <- "data/c_submodel_data/fisheries.gpkg"

#### intermediate directories
lps_gpkg <- "data/b_intermediate_data/westport_large_pelagic_survey.gpkg"

#####################################

# inspect layers within geopackage
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
export_name <- "large_pelagic_survey"

## setback distance (in meters)
setback <- 16093.4

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# function
## z-membership function
### Adapted from https://www.mathworks.com/help/fuzzy/zmf.html
zmf_function <- function(large_pelagic_survey){
  
  # calculate minimum value
  min <- min(large_pelagic_survey$lps_value)
  
  # calculate maximum value
  max <- max(large_pelagic_survey$lps_value)
  
  # calculate z-score minimum value
  ## this ensures that no value gets a value of 0
  z_max <- max + (max * 1 / 10000)
  
  # create a field and populate with the value determined by the z-shape membership scalar
  large_pelagic_survey <- large_pelagic_survey %>%
    # calculate the z-shape membership value (more desired values get a score of 1 and less desired values will decrease till 0.01)
    ## ***Note: in other words, habitats with higher richness values will be closer to 0
    dplyr::mutate(lps_z_value = ifelse(lps_value == min, 1, # if value is equal to minimum, score as 1
                                       # if value is larger than minimum but lower than mid-value, calculate based on scalar equation
                                       ifelse(lps_value > min & lps_value < (min + z_max) / 2, 1 - 2 * ((lps_value - min) / (z_max - min)) ** 2,
                                              # if value is lower than z_maximum but larger than than mid-value, calculate based on scalar equation
                                              ifelse(lps_value >= (min + z_max) / 2 & lps_value < z_max, 2 * ((lps_value - z_max) / (z_max - min)) ** 2,
                                                     # if value is equal to maximum, value is equal to 0.01 [all other values should get an NA]
                                                     ifelse(lps_value == z_max, 0.01, NA)))))
  
  # return the layer
  return(large_pelagic_survey)
}

#####################################
#####################################

# load data
## large pelagic survey data
lps <- sf::st_read(dsn = data_dir,
                            # large pelagic survey
                            layer = sf::st_layers(data_dir)[[1]][1]) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs) %>%
  # apply 16093.4-meter setback
  sf::st_buffer(x = ., dist = setback)

#####################################

## study region
westport_region <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area", sep = "_"))

## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

#####################################
#####################################

# limit data to study region
westport_lps <- lps %>%
  # obtain only large pelagic survey in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "large pelagic survey" for summary
  dplyr::mutate(layer = "large pelagic survey")

#####################################
#####################################

# large pelagic survey hex grids
westport_lps_hex <- westport_hex[westport_lps, ] %>%
  # spatially join large pelagic survey values to Westport hex cells
  sf::st_join(x = .,
              y = westport_lps,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer,
                cluster) %>%
  # rename "cluster" field
  dplyr::rename(lps_value = cluster) %>%
  # calculate z-values
  zmf_function() %>%
  # relocate the z-value field
  dplyr::relocate(lps_z_value, .after = lps_value) %>%
  # group by the index values as there are duplicates
  dplyr::group_by(index) %>%
  # summarise the fisheries score values
  ## take the maximum value of the large pelagic survey score for any that overlap
  ## ***Note: this will provide the most conservation given that high values are less desirable
  dplyr::summarise(lps_max = max(lps_z_value))

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_lps_hex, dsn = fisheries_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## large pelagic survey geopackage
sf::st_write(obj = lps, dsn = lps_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_lps, dsn = lps_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
