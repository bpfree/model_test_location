
library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")
source("./src/model_functions.R")


calculate_model <- function(full_model_object){
  # get number of submodels 
  n_sms = length(full_model_object$submodels)
  # get hex grid and id_cols from global variable
  id_cols = get(full_model_object$id_cols_var)
  fm_hex_df = get(full_model_object$hex_grid_var) %>%
    st_drop_geometry(.) %>%
    select(all_of(id_cols))
  # run each submodel 1 by 1 and load the sm values
  sm_names = c()
  for(n in seq(n_sms)){
    # load and score the submodel object
    sm_data = calculate_submodel(full_model_object$submodels[[n]])
    # add sm data onto empty hex object
    fm_hex_df = left_join(fm_hex_df,
        sm_data %>% select(all_of(c(id_cols, full_model_object$submodels[[n]]$name))),
        by=id_cols)
    # keep name of the layers
    sm_names = c(sm_names, c(full_model_object$submodels[[n]]$name))
  }
  # calculate weighted geom mean of submodel values
  fm_vals = geom_mean_columns(my_df=fm_hex_df, cols=sm_names,
                  id_cols=id_cols, weights=full_model_object$weights)
  # rejoin values to the hex and name the column to the model name
  fm_hex_df = left_join(fm_hex_df,
               fm_vals %>% rename(!!full_model_object$name := vals),
               by=id_cols )
  # return
  return(fm_hex_df)
}




# 
# test_plot = ggplot(hex_values) +
#   theme_bw() +
#   geom_point(aes(x=vals, y=depth))
# 

