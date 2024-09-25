

library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")
source("./src/model_functions.R")

model_name = "test_model"
hex_grid_global <<- st_read("./data/test_grid_ak_small.gpkg")
id_cols_global <<- c("GRID_ID", "study_area")
submodel_names = c("submodel_1", "submodel_2")
submodel_weights = c(1,2)

model_layers = list(layer_1, layer_2, layer_3, layer_4, layer_5, layer_comb)


temp <- group_and_index_model_layers(model_layers)

model_layers = temp[[1]]
layer_info = temp[[2]]

#

full_model_object <- create_fullmodel_object(model_layers, layer_info, submodel_names, submodel_weights, model_name)


