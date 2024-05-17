#########################################################
### 18. Vessel trip reporting (VTR) -- all gear types ###
#########################################################

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
               #rgdal,
               rgeoda,
               #rgeos,
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
#### vessel trip reporting
data_dir <- "data/a_raw_data/VTR_allGearTypes/"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### fisheries
fisheries_gpkg <- "data/c_submodel_data/fisheries.gpkg"

#### intermediate directories
vtr_all_gpkg <- "data/b_intermediate_data/westport_vtr_all.gpkg"

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

### EPSG:26919 is NAD83 / UTM 19N (https://epsg.io/26919)
vtr_crs <- "EPSG:26919"

## layer names
export_name <- "vtr_all_gear"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# function
## z-membership function
### Adapted from https://www.mathworks.com/help/fuzzy/zmf.html
zmf_function <- function(raster){
  
  # calculate minimum value
  min <- terra::minmax(raster)[1,]
  
  # calculate maximum value
  max <- terra::minmax(raster)[2,]
  
  # calculate z-score minimum value
  ## this ensures that no value gets a value of 0
  z_max <- max + (max * 1 / 1000)
  
  # calculate z-scores (more desired values get score of 1 while less desired will decrease till 0)
  z_value <- ifelse(raster[] == min, 1, # if value is equal to minimum, score as 1
                    # if value is larger than minimum but lower than mid-value, calculate based on reduction equation
                    ifelse(raster[] > min & raster[] < (min + z_max) / 2, 1 - 2 * ((raster[] - min) / (z_max - min)) ** 2,
                           # if value is larger than mid-value but lower than maximum, calculate based on equation
                           ifelse(raster[] >= (min + z_max) / 2 & raster[] < z_max, 2*((raster[] - z_max) / (z_max - min)) ** 2,
                                  # if value is equal to maximum, score min - (min * 1 / 1000); otherwise give NA
                                  ifelse(raster[] == z_max, 0, NA))))
  
  # set values back to the original raster
  zvalues <- terra::setValues(raster, z_value)
  plot(zvalues)
  
  # return the raster
  return(zvalues)
}

#####################################
#####################################

# load data
## VTR (all gear types)
vtr_all <- terra::rast(paste(data_dir, "VTR_allGearTypes", sep = "/"))

## study region
westport_region <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area", sep = "_")) %>%
  # change projection to match AIS data coordinate reference system
  sf::st_transform(crs = vtr_crs)

### Inspect study region coordinate reference system
cat(crs(westport_region))

## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

#####################################
#####################################

# limit VTR (all gear types) data to study region

vtr_all_raster <- terra::crop(x = vtr_all,
                              # crop using study region
                              y = westport_region,
                              # mask using study region (T = True)
                              mask = T,
                              extend = T)
plot(vtr_all_raster)

#####################################
#####################################

# rescale using z-membership function
vtr_all_z <- vtr_all_raster %>%
  # apply the z-membership function
  zmf_function()

#####################################
#####################################

# convert raster to vector data (as polygons)
# convert to polygon
westport_vtr_all_polygon <- terra::as.polygons(x = vtr_all_z,
                                           # do not aggregate all similar values together as single feature
                                           aggregate = F,
                                           # use the values from original raster
                                           values = T) %>%
  # change to simple feature (sf)
  sf::st_as_sf() %>%
  # simplify column name to "vtr" (this is the first column of the object, thus the colnames(.)[1] means take the first column name from the vtr object)
  dplyr::rename(vtr = colnames(.)[1]) %>%
  # add field "layer" and populate with "vms"
  dplyr::mutate(layer = "vtr") %>%
  # limit to the study region
  rmapshaper::ms_clip(clip = westport_region) %>%
  # reproject data into a coordinate system (NAD 1983 UTM Zone 18N) that will convert units from degrees to meters
  sf::st_transform(crs = crs)

## inspect vectorized rescaled vtr data (***warning: lots of data, so will take a long time to load; comment out unless want to display data)
# plot(westport_vtr_polygon)

#####################################
#####################################

# vessel trip reporting hex grids
westport_vtr_all_hex <- westport_hex[westport_vtr_all_polygon, ] %>%
  # spatially join vessel trip reporting values to Westport hex cells
  sf::st_join(x = .,
              y = westport_vtr_all_polygon,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer,
                vtr) %>%
  # group by the index values as there are duplicates
  dplyr::group_by(index) %>%
  # summarise the fisheries score values
  ## take the maximum value of the AIS score for any that overlap
  ## ***Note: this will provide the most conservation given that
  ##          high values are less desirable
  dplyr::summarise(vtr_max = max(vtr))

#####################################
#####################################

# export data
## fisheries geopackage
sf::st_write(obj = westport_vtr_all_hex, dsn = fisheries_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## vms geopackage
sf::st_write(obj = westport_vtr_all_polygon, dsn = vtr_all_gpkg, layer = paste(region, export_name, "polygon", date, sep = "_"), append = F)
sf::st_write(obj = westport_vtr_all_hex, dsn = vtr_all_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## vms raster
vtr_raster <- dir.create(paste0("data/b_intermediate_data/vtr_data"))
raster_dir <- "data/b_intermediate_data/vtr_data"

terra::writeRaster(vtr_all, filename = file.path(raster_dir, paste("vtr_all-gear.grd")), overwrite = T)
terra::writeRaster(vtr_all_raster, filename = file.path(raster_dir, paste("westport_vtr_all.grd")), overwrite = T)
terra::writeRaster(vtr_all_z, filename = file.path(raster_dir, paste("westport_vtr_all_rescaled.grd")), overwrite = T)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
