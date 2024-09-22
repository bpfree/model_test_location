
library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")
source("./src/model_functions.R")


calculate_submodel <- function(submodel_object){
  # get # of layers in submodel
  n_lyrs = length(submodel_object$layers)
  # get hex grid and id_cols from global variable
  id_cols = get(submodel_object$id_cols_var)
  hex_sf = get(submodel_object$hex_grid_var) %>%
    select(all_of(id_cols))
  # load each submodel layer into data frame
  lyr_names = c()
  for(n in seq(n_lyrs)){
    # load and score the layer object
    lyr_data = load_and_score_model_layer(submodel_object$layers[[n]])
    # add layer data onto empty hex object
    hex_sf = left_join(hex_sf, lyr_data, by=id_cols)
    # keep name of the layers
    lyr_names = c(lyr_names, c(submodel_object$layers[[n]]$layer_name))
  }
  # calculate weighted geom mean of submodel layers
  sm_vals = geom_mean_columns(my_df=hex_sf,
              cols=lyr_names, id_cols=id_cols, weights=submodel_object$weights)
  # rejoin values to the hex and name the column to the submodel name
  hex_sf = left_join(hex_sf,
                     sm_vals %>% rename(!!submodel_object$name := vals),
                     by=id_cols )
  
}




# 
# test_plot = ggplot(hex_values) +
#   theme_bw() +
#   geom_point(aes(x=vals, y=depth))
# 

