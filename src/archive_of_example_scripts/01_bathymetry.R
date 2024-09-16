#####################
### 1. Bathymetry ###
#####################

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
data_dir <- "data/a_raw_data/bathymetry"

#### study area grid
study_region_gpkg <- "data/b_intermediate_data/westport_study_area.gpkg"

### Output directories
#### Intermediate directories
intermediate_dir <- "data/b_intermediate_data"

#### Bathymetry directory
dir.create(paste0(intermediate_dir, "/",
                  "bathymetry"))

bathymetry_dir <- "data/b_intermediate_data/bathymetry"

#####################################
#####################################

# set parameters
## designate region name
region <- "westport"

## coordinate reference system
### EPSG:26918 is NAD83 / UTM 18N (https://epsg.io/26918)
crs <- "EPSG:26918"

bath_crs <- "EPSG:4269"

## layer names
export_name <- "bathymetry_boundary"

## designate date
date <- format(Sys.Date(), "%Y%m%d")

#####################################
#####################################

# Load data

## ***Note: Can find bathymetry data for the United States and associated areas here: https://www.ncei.noaa.gov/maps/bathymetry/
## 1.) In the right panel, mark "DEM Footprints" (can also uncheck any other layers so easier to read)
## 2.) Zoom into area(s) of interest
## 3.) Click on the map within area(s) of interest
## 4.) Within the pop-up window in the map panel, expand the NCEI Digital Elevation Models directory
## 5.) Click the source that is desired (clicking magnifying glass to right will center map view on that data source and extent)
## 6.) Click "Link to Metadata" to open new tab for data source and download data

### ***Note: for these data, mark the option for Continuously Updated Digital Elevation Model (CUDEM) under the Digital
###          elevation models dropdown

### ***Note: Also helpful to mark the option to display DEM footprints

#### Data are spread across two major data sourcs: CUDEM third arc-second resolution and ninth arc-second resolution
#### ***Note: for the 1/9-arc second data (~3m), the data encompass three datasets
####    a.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x00_2018v1.tif
####    b.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x25_2018v1.tif
####    c.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x50_2018v1.tif
bath_9th_1 <- terra::rast(paste(data_dir, "ncei19_n41x50_w071x00_2018v1.tif", sep = "/"))
bath_9th_2 <- terra::rast(paste(data_dir, "ncei19_n41x50_w071x25_2018v1.tif", sep = "/"))
bath_9th_3 <- terra::rast(paste(data_dir, "ncei19_n41x50_w071x50_2018v1.tif", sep = "/"))

#### ***Note: for the 1/3-arc second data (~10m), the data encompass three datasets
####    a.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x00_2021v1.tif
####    b.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x25_2021v1.tif
####    c.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x50_2021v1.tif
bath_3rd_1 <- terra::rast(paste(data_dir, "ncei13_n41x25_w071x00_2021v1.tif", sep = "/"))
bath_3rd_2 <- terra::rast(paste(data_dir, "ncei13_n41x25_w071x25_2021v1.tif", sep = "/"))
bath_3rd_3 <- terra::rast(paste(data_dir, "ncei13_n41x25_w071x50_2021v1.tif", sep = "/"))

#####################################

# ## study region
# westport_region <- sf::st_read(dsn = study_region_gpkg, layer = paste(region, "study_region", sep = "_")) %>%
#   sf::st_transform(x = ., crs = bath_crs)
# 
# cat(crs(westport_region))

#####################################
#####################################

# Inspect the data
## Coordinate reference systems
terra::crs(bath_9th_1) # EPSG:4269
terra::crs(bath_9th_2) # EPSG:4269
terra::crs(bath_9th_3) # EPSG:4269

cat(crs(bath_9th_1))
cat(crs(bath_9th_2))
cat(crs(bath_9th_3))

terra::crs(bath_3rd_1) # EPSG:4269
terra::crs(bath_3rd_2) # EPSG:4269
terra::crs(bath_3rd_3) # EPSG:4269

cat(crs(bath_3rd_1))
cat(crs(bath_3rd_2))
cat(crs(bath_3rd_3))

## Resolution
terra::res(bath_9th_1) # 3.08642e-05 3.08642e-05
terra::res(bath_9th_2) # 3.08642e-05 3.08642e-05
terra::res(bath_9th_3) # 3.08642e-05 3.08642e-05

terra::res(bath_3rd_1) # 9.259259e-05 9.259259e-05
terra::res(bath_3rd_2) # 9.259259e-05 9.259259e-05
terra::res(bath_3rd_3) # 9.259259e-05 9.259259e-05

#####################################
#####################################

## Disaggregate the resolution to match the other datasets
### Calculate the factor between the resolutions (3)
factor <- round(terra::res(bath_3rd_1)[1] / terra::res(bath_9th_1)[1], 0) 

### Disaggreate the resolution
bath_3rd_1_disagg <- terra::disagg(x = bath_3rd_1,
                                   # resolution factor
                                   fact = factor)
bath_3rd_2_disagg <- terra::disagg(x = bath_3rd_2,
                                   # resolution factor
                                   fact = factor)
bath_3rd_3_disagg <- terra::disagg(x = bath_3rd_3,
                                   # resolution factor
                                   fact = factor)

terra::res(bath_3rd_1_disagg) # 3.08642e-05 3.08642e-05
terra::res(bath_3rd_2_disagg) # 3.08642e-05 3.08642e-05
terra::res(bath_3rd_3_disagg) # 3.08642e-05 3.08642e-05

### Set other aspects of the data
#### Units
units(bath_3rd_1_disagg) <- "meters"
units(bath_3rd_2_disagg) <- "meters"
units(bath_3rd_3_disagg) <- "meters"

# #### Variable names
# varnames(bath_3rd_1_disagg) <- "z"

### Reinspect data
cat(crs(bath_3rd_1_disagg))

#####################################
#####################################

# Combine the bathymetry datasets together
### Westport bathymetry using 1/9-arc second datasets
westport_bath <- terra::mosaic(bath_9th_1,
                               bath_9th_2,
                               bath_9th_3,
                               bath_3rd_1_disagg,
                               bath_3rd_2_disagg,
                               bath_3rd_3_disagg,
                               fun = "mean") # %>%
  # # crop bathymetry data to the Westport study area
  # terra::crop(westport_region,
  #             # use the Westport study area to mask the data
  #             mask = T)
dim(westport_bath)
plot(westport_bath)

#####################################

# change projection back to NAD83 / UTM 18N (https://epsg.io/26918)
westport_bath <- terra::project(x = westport_bath, y = crs)
cat(crs(westport_bath))

# inspect minimum and maximum values
terra::minmax(westport_bath)[1] # top depth
terra::minmax(westport_bath)[2] # bottom depth

#####################################

# limit area to locations where bathymetry falls between -40 and -20 meters
westport_bath_boundary <- terra::ifel(westport_bath < -40, NA, terra::ifel(westport_bath > -20, NA, westport_bath))

# plot new raster
plot(westport_bath_boundary)

# inspect minimum and maximum values
terra::minmax(westport_bath_boundary)[1] # top depth
terra::minmax(westport_bath_boundary)[2] # bottom depth

#####################################

# convert boundary to a polygon
westport_boundary <- terra::as.polygons(x = westport_bath_boundary) %>%
  # set as sf
  sf::st_as_sf(westport_boundary) %>%
  # create field called "boundary"
  dplyr::mutate(boundary = "boundary") %>%
  # select the "boundary" field
  dplyr::select(boundary) %>%
  # group all rows by the different elements with "boundary" field -- this will create a row for the grouped data
  dplyr::group_by(boundary) %>%
  # summarise all those grouped elements together -- in effect this will create a single feature
  dplyr::summarise()

#####################################
#####################################

# export boundary
sf::st_write(obj = westport_boundary, dsn = study_region_gpkg, layer = paste(region, export_name, date, sep = "_"), append = F)

# export raster file
terra::writeRaster(westport_bath_boundary, filename = file.path(bathymetry_dir, "westport_bathymetry_boundary.grd"), overwrite = T)
terra::writeRaster(westport_bath, filename = file.path(bathymetry_dir, "westport_bath.grd"), overwrite = T)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
