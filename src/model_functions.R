library(matrixStats)
library(dplyr)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")

# calculate weighted geometric means of columns in a dataframe
geom_mean_columns <- function(my_df, cols, id_cols=c(), weights=NULL){
  # subset the data into only what columns are needed
  my_df <- my_df %>% select(all_of(c(id_cols, cols)))
  # if my_df is a sf dataframe it will retain the extra geom. column
  if(ncol(my_df) == length(c(id_cols, cols))+1){
    my_df = st_drop_geometry(my_df) }
  # convert data columns into a matrix
  my_mtrx = as.matrix(my_df %>% select(all_of(cols)))
  # initialize even weighting if none given
  if(is.null(weights)){ weights = rep(1/ncol(my_mtrx), ncol(my_mtrx)) }
  ### run rowwise weighted mean calculation by using matrix math
  # transpose the matrix and take the columwise exponent based on the weights
  # then transpose back to the original format
  my_mtrx = t(t(my_mtrx)^weights)
  # get product of row values and raise to the power of 1/ the sum of the weights
  vals = matrixStats::rowProds(my_mtrx)^(1/sum(weights))
  # return output values
  if(length(id_cols)==0){return(vals)
  }else{  # if id columns given return dataframe with id columns
    my_df = my_df %>% select(all_of(id_cols))
    my_df$vals = vals
    return(my_df)
  }
}

###

# from input settings contained in a layer run a loading function and 
 # a scoring function and return the values (with the id columns)
load_and_score_model_layer <- function(layer_object){
  # get lists to map string inputs to functions 
  extraction_functions <- list(
    "raster" = load_raster_values,
    "polygon_intersection" = load_polygon_intersection_boolean,
    "polygon_value" = load_polygon_intersection_value,
    "scored_hex" = load_scored_hex_grid )
  
  membership_functions <- list(
    "z_membership" = z_membership,
    "s_membership" = s_membership,
    "linear_membership" = linear_membership,
    "quantile_membership" = quantile_membership,
    "bin_membership" = bin_membership,
    "mapped_membership" = mapped_membership,
    "none" = \ (x) x)
  
  ######
  # get hex grid and id_cols from global variable
  id_cols = get(layer_object$id_cols_var)
  hex_sf = get(layer_object$hex_grid_var) %>%
    select(all_of(id_cols))
  
  ### load in the data
  # set up the list of load arguments
  args_list = c( list(poly_extr=hex_sf, fp_in=layer_object$fp_data_in, id_cols=id_cols),
                 layer_object$load_params)
  # run the load function
  hex_values = do.call(extraction_functions[[layer_object$input_type]],
                       args = args_list )
  
  ### score the layer
  # set up the list of score arguments
  args_list = c( list(x=hex_values$vals), layer_object$score_params )
  # run the scoring function
  hex_values[[layer_object$layer_name]] = do.call(
    membership_functions[[layer_object$mem_fun]],
    args = args_list )
  
  # return
  return(hex_values %>% select(-vals))
}

###



