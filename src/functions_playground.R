
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
  sm_hex_df = get(submodel_object$hex_grid_var) %>%
    st_drop_geometry(.) %>%
    select(all_of(id_cols))
  # load each submodel layer into data frame
  lyr_names = c()
  for(n in seq(n_lyrs)){
    # load and score the layer object
    lyr_data = load_and_score_model_layer(submodel_object$layers[[n]])
    # add layer data onto empty hex object
    sm_hex_df = left_join(sm_hex_df, lyr_data, by=id_cols)
    # keep name of the layers
    lyr_names = c(lyr_names, c(submodel_object$layers[[n]]$layer_name))
  }
  # calculate weighted geom mean of submodel layers
  sm_vals = geom_mean_columns(my_df=sm_hex_df,
              cols=lyr_names, id_cols=id_cols, weights=submodel_object$weights)
  # rejoin values to the hex and name the column to the submodel name
  sm_hex_df = left_join(sm_hex_df,
                     sm_vals %>% rename(!!submodel_object$name := vals),
                     by=id_cols )
  # return
  return(sm_hex_df)
}




# 
# test_plot = ggplot(hex_values) +
#   theme_bw() +
#   geom_point(aes(x=vals, y=depth))
# 

