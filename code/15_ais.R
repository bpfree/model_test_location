#################################################
### 15. Automatic identification system (AIS) ###
#################################################

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
data_dir <- "data/a_raw_data/ais_2022/ais_2022_year"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### output directories
#### industry, transportation, navigation
industry_gpkg <- "data/c_submodel_data/industry_transportation_navigation.gpkg"

#### intermediate directories
ais_gpkg <- "data/b_intermediate_data/westport_ais.gpkg"

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

### EPSG:3857 is WGS 84 / Pseudo-Mercator -- Spherical Mercator, Google Maps, OpenStreetMap, Bing, ArcGIS, ESRI (https://epsg.io/3857)
ais_crs <- "EPSG:3857"

## layer names
export_name <- "ais"

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
  
  # return the raster
  return(zvalues)
}

#####################################
#####################################

# load data
## AIS 2022 data (source: https://services.northeastoceandata.org/downloads/AIS/AIS2022_Annual.zip)
### metadata: https://www.northeastoceandata.org/files/metadata/Themes/AIS/AllAISVesselTransitCounts2022.pdf
ais <- terra::rast(paste(data_dir, "w001001.adf", sep = "/"))
crs(ais) <- ais_crs

### inspect data
#### plot data
plot(ais)

#### minimum and maximum values
terra::minmax(ais)[1]
terra::minmax(ais)[2]

### coordinate reference system
cat(crs(ais))

#####################################

## study region
westport_region <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area", sep = "_")) %>%
  # change projection to match AIS data coordinate reference system
  sf::st_transform(crs = ais_crs)

### Inspect study region coordinate reference system
cat(crs(westport_region))

## hex grid
westport_hex <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "area_hex", sep = "_"))

#####################################
#####################################

plot(westport_region)

# limit data to study region
westport_ais <- terra::crop(x = ais,
                            # crop using study region
                            y = westport_region,
                            # mask using study region (T = True)
                            mask = T)

plot(westport_ais)

#####################################
#####################################

# rescale AIS values using a z-membership function
ais_z <- westport_ais %>%
  zmf_function()

## inspect rescaled data
plot(ais_z)

#####################################
#####################################

# convert raster to vector data (as polygons)
# convert to polygon
westport_ais_polygon <- terra::as.polygons(x = ais_z,
                                          # do not aggregate all similar values together as single feature
                                          aggregate = F,
                                          # use the values from original raster
                                          values = T) %>%
  # change to simple feature (sf)
  sf::st_as_sf() %>%
  # simplify column name to "ais" (this is the first column of the object, thus the colnames(.)[1] means take the first column name from the ais object)
  dplyr::rename(ais = colnames(.)[1]) %>%
  # add field "layer" and populate with "ais"
  dplyr::mutate(layer = "ais") %>%
  # limit to the study region
  rmapshaper::ms_clip(clip = westport_region) %>%
  # reproject data into a coordinate system (NAD 1983 UTM Zone 18N) that will convert units from degrees to meters
  sf::st_transform(crs = crs)

## inspect vectorized rescaled AIS data (***warning: lots of data, so will take a long time to load; comment out unless want to display data)
# plot(westport_ais_polygon)

#####################################
#####################################

# vessel trip reporting hex grids
westport_ais_hex <- westport_hex[westport_ais_polygon, ] %>%
  # spatially join vessel trip reporting values to Westport hex cells
  sf::st_join(x = .,
              y = westport_ais_polygon,
              join = st_intersects) %>%
  # select fields of importance
  dplyr::select(index, layer,
                ais) %>%
  # group by the index values as there are duplicates
  dplyr::group_by(index) %>%
  # summarise the fisheries score values
  ## take the maximum value of the AIS score for any that overlap
  ## ***Note: this will provide the most conservation given that
  ##          high values are less desirable
  dplyr::summarise(ais_max = max(ais))

#####################################
#####################################

# export data
## industry, transportation, navigation geopackage
sf::st_write(obj = westport_ais_hex, dsn = industry_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## ais geopackage
sf::st_write(obj = westport_ais_polygon, dsn = ais_gpkg, layer = paste(region, export_name, "polygon", date, sep = "_"), append = F)
sf::st_write(obj = westport_ais_hex, dsn = ais_gpkg, layer = paste(region, "hex", export_name, date, sep = "_"), append = F)

## ais raster
ais_raster <- dir.create(paste0("data/b_intermediate_data/ais_data"))
raster_dir <- "data/b_intermediate_data/ais_data"

terra::writeRaster(westport_ais, filename = file.path(raster_dir, paste("westport_ais_2022.grd")), overwrite = T)
terra::writeRaster(ais, filename = file.path(raster_dir, paste("ais_2022.grd")), overwrite = T)
terra::writeRaster(ais_z, filename = file.path(raster_dir, paste("westport_ais_2022_rescaled.grd")), overwrite = T)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
