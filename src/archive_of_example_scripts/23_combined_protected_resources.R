########################################
### 23. Combined protected resources ###
########################################

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
#### combined protected resources
data_dir <- "data/a_raw_data/combined_protected_resources"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### natural and cultural resources
natural_cultural_gpkg <- "data/c_submodel_data/natural_cultural.gpkg"

#### intermediate directories
comb_prot_resources_gpkg <- "data/b_intermediate_data/westport_combined_protected_resources.gpkg"

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
export_name <- "combined_protected_resources"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# function
## z-membership function
### Adapted from https://www.mathworks.com/help/fuzzy/zmf.html
zmf_function <- function(combined_protected_resources){
  
  # calculate minimum value
  min <- min(combined_protected_resources$cpr_value)
  
  # calculate maximum value
  max <- max(combined_protected_resources$cpr_value)
  
  # calculate z-score minimum value
  ## this ensures that no value gets a value of 0
  z_max <- max + (max * 1 / 1000)
  
  # create a field and populate with the value determined by the z-shape membership scalar
  combined_protected_resources <- combined_protected_resources %>%
    # calculate the z-shape membership value (more desired values get a score of 1 and less desired values will decrease till 0.01)
    ## ***Note: in other words, habitats with higher richness values will be closer to 0
    dplyr::mutate(cpr_z_value = ifelse(cpr_value == min, 1, # if value is equal to minimum, score as 1
                                   # if value is larger than minimum but lower than mid-value, calculate based on scalar equation
                                   ifelse(cpr_value > min & cpr_value < (min + z_max) / 2, 1 - 2 * ((cpr_value - min) / (z_max - min)) ** 2,
                                          # if value is lower than z_maximum but larger than than mid-value, calculate based on scalar equation
                                          ifelse(cpr_value >= (min + z_max) / 2 & cpr_value < z_max, 2 * ((cpr_value - z_max) / (z_max - min)) ** 2,
                                                 # if value is equal to maximum, value is equal to 0.01 [all other values should get an NA]
                                                 ifelse(cpr_value == z_max, 0.01, NA)))))
  
  # return the layer
  return(combined_protected_resources)
}

#####################################
#####################################

# load data
## combined protected resources data
comb_prot_resources <- sf::st_read(dsn = file.path(paste(data_dir, "final_PRD_CEATL_WP.shp", sep = "/"))) %>%
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
westport_comb_prot_resources <- comb_prot_resources %>%
  # obtain only combined protected resources in the study area
  rmapshaper::ms_clip(target = .,
                      clip = westport_region) %>%
  # create field called "layer" and fill with "combined protected resources" for summary
  dplyr::mutate(layer = "combined protected resources")

#####################################
#####################################

# combined protected resources hex grids
westport_comb_prot_resources_hex <- westport_hex[westport_comb_prot_resources, ] %>%
  # spatially join combined protected resources values to Westport hex cells
  sf::st_join(x = .,
              y = westport_comb_prot_resources,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer, GEO_MEAN) %>%
  # rename "GEO_MEAN" field
  dplyr::rename(cpr_value = GEO_MEAN) %>%
  # calculate z-values
  zmf_function() %>%
  # relocate the z-value field
  dplyr::relocate(cpr_z_value, .after = cpr_value) %>%
  # group by the index values as there are duplicates
  dplyr::group_by(index) %>%
  # summarise the fisheries score values
  ## take the maximum value of the combined protected resource score for any that overlap
  ## ***Note: this will provide the most conservation given that high values are less desirable
  dplyr::summarise(cpr_max = max(cpr_z_value))

#####################################
#####################################

# export data
## constraints geopackage
sf::st_write(obj = westport_comb_prot_resources_hex, dsn = natural_cultural_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## combined protected resources geopackage
sf::st_write(obj = comb_prot_resources, dsn = comb_prot_resources_gpkg, layer = paste(export_name, date, sep = "_"), append = F)
sf::st_write(obj = westport_comb_prot_resources, dsn = comb_prot_resources_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
