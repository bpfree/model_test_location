############################
### 4. Define Study Area ###
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
aoi_dir <- "data/a_raw_data/AOI_polygon_shp"
study_dir <- "data/a_raw_data/studyRegion_polygon"
westport_gpkg <- "data/a_raw_data/Westport_FinalGeoPackage.gpkg"

data_dir <- "data/b_intermediate_data/westport_study_area.gpkg"

#####################################

sf::st_layers(dsn = data_dir,
              do_count = T)

#####################################
#####################################

# set parameters
## designate region name
region <- "westport"

## coordinate reference system
### EPSG:26918 is NAD83 / UTM 18N (https://epsg.io/26918)
crs <- "EPSG:26918"

#####################################
#####################################

# load data
## bathymetry boundary
bathymetry <- sf::st_read(dsn = data_dir,
                          layer = sf::st_layers(data_dir)[[1]][grep(pattern = "bathymetry",
                                                                    sf::st_layers(dsn = data_dir, do_count = T)[[1]])])

## federal waters
federal_waters <- sf::st_read(dsn = data_dir,
                              layer = sf::st_layers(data_dir)[[1]][grep(pattern = "federal",
                                                                        sf::st_layers(dsn = data_dir, do_count = T)[[1]])])

## Westport town 20-mile setback
town_20mi <- sf::st_read(dsn = data_dir,
                         layer = sf::st_layers(data_dir)[[1]][grep(pattern = "town",
                                                                   sf::st_layers(dsn = data_dir, do_count = T)[[1]])])

#####################################

## area of interest
aoi_poly <- sf::st_read(dsn = file.path(paste(aoi_dir, "AOI_polygon.shp", sep = "/"))) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs)

## study region
study_region <- sf::st_read(dsn = file.path(paste(study_dir, "studyRegion_constraints_polygon.shp", sep = "/"))) %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs)

#####################################

## original hex grid
westport_grid <- sf::st_read(dsn = westport_gpkg, layer = "studyArea_hexGrids_constrained") %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs) %>%
  # create and index location
  dplyr::mutate(index = row_number()) %>%
  dplyr::relocate(index,
                  .before = GRID_ID)

#####################################
#####################################

westport_area <- bathymetry %>%
  rmapshaper::ms_clip(federal_waters) %>%
  rmapshaper::ms_clip(town_20mi)

plot(westport_area)

#####################################
#####################################

# Hexagon area = ((3 * sqrt(3))/2) * side length ^ 2 (https://pro.arcgis.com/en/pro-app/latest/tool-reference/data-management/generatetesellation.htm)
# 1 acre equals approximately 4064.86 square meters
# 10 acres = 40468.6 square meters
# 40468.6 = ((3 * sqrt(3))/2) * side length ^ 2
# 40468.6 * 2 = 3 * sqrt(3) * side length ^ 2 --> 80937.2
# 80937.2 / 3 = sqrt(3) * side length ^ 2 --> 26979.07
# 26979.07 ^ 2 = 3 * side length ^ 4 --> 727870218
# 727870218 / 3 = side length ^ 4 --> 242623406
# 242623406 ^ (1/4) = side length --> 124.8053

# Create 10-acre grid around study region
study_region_grid <- sf::st_make_grid(x = study_region,
                                   ## see documentation on what cellsize means when relating to hexagons: https://github.com/r-spatial/sf/issues/1505
                                   ## cellsize is the distance between two vertices (short diagonal --> d = square root of 3 * side length)
                                   ### So in this case, square-root of 3 * 124.8053 = 1.73205080757 * 124.8053 = 216.1691
                                   cellsize = 216.1691,
                                   # make hexagon (TRUE will generate squares)
                                   square = FALSE,
                                   # make hexagons orientation with a flat topped (FALSE = pointy top)
                                   flat_topped = TRUE) %>%
  # convert back as sf
  sf::st_as_sf() %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs)

# subset by location: hexagonal grids that intersect with study area
study_region_hex <- study_region_grid[study_region, ] %>%
  # add field "index" that will be populated with the row_number
  dplyr::mutate(index = row_number())

#####################################

# Create 10-acre grid around westport area
westport_area_grid <- sf::st_make_grid(x = westport_area,
                                      ## see documentation on what cellsize means when relating to hexagons: https://github.com/r-spatial/sf/issues/1505
                                      ## cellsize is the distance between two vertices (short diagonal --> d = square root of 3 * side length)
                                      ### So in this case, square-root of 3 * 124.8053 = 1.73205080757 * 124.8053 = 216.1691
                                      cellsize = 216.1691,
                                      # make hexagon (TRUE will generate squares)
                                      square = FALSE,
                                      # make hexagons orientation with a flat topped (FALSE = pointy top)
                                      flat_topped = TRUE) %>%
  # convert back as sf
  sf::st_as_sf() %>%
  # change to correct coordinate reference system (EPSG:26918 -- NAD83 / UTM 18N)
  sf::st_transform(x = ., crs = crs)

# subset by location: hexagonal grids that intersect with study area
westport_area_hex <- westport_area_grid[westport_area, ] %>%
  # add field "index" that will be populated with the row_number
  dplyr::mutate(index = row_number())

#####################################
#####################################

# export data
## original grid
sf::st_write(obj = westport_grid, dsn = data_dir, layer = paste(region, "original_grid", sep = "_"), append = F)

## study area
### area of interest
sf::st_write(obj = aoi_poly, dsn = data_dir, layer = paste(region, "aoi_polygon", sep = "_"), append = F)

### study region
sf::st_write(obj = study_region, dsn = data_dir, layer = paste(region, "study_region", sep = "_"), append = F)
sf::st_write(obj = study_region_grid, dsn = data_dir, layer = paste(region, "study_region_grid", sep = "_"), append = F)
sf::st_write(obj = study_region_hex, dsn = data_dir, layer = paste(region, "study_region_hex", sep = "_"), append = F)

sf::st_write(obj = westport_area, dsn = data_dir, layer = paste(region, "area", sep = "_"), append = F)
sf::st_write(obj = westport_area_grid, dsn = data_dir, layer = paste(region, "area_grid", sep = "_"), append = F)
sf::st_write(obj = westport_area_hex, dsn = data_dir, layer = paste(region, "area_hex", sep = "_"), append = F)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
