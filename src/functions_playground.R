
library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")
source("./src/model_functions.R")

combine_model_layers <- function(layers){
  
  
  
}


poly_extr = st_read("./data/test_grid_ak.gpkg") %>%
  filter(study_area == "Juneau")
fp_in = "./data/ak_polygon_juneau_test.gpkg"
id_cols <- c("GRID_ID", "study_area")

dummy = load_polygon_intersection_value(poly_extr, fp_in, "STAT_AREA", id_cols, buffer=100)

# 
# test_plot = ggplot(hex_values) +
#   theme_bw() +
#   geom_point(aes(x=vals, y=depth))
# 



