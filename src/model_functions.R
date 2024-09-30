library(matrixStats)
library(dplyr)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")

# calculate weighted geometric means of columns in a dataframe
geom_mean_columns <- function(my_df, cols, id_cols=c(),
                              weights=NULL, na_replace=1){
  # subset the data into only what columns are needed
  my_df <- my_df %>% select(all_of(c(id_cols, cols)))
  # if my_df is a sf dataframe it will retain the extra geom. column
  if(ncol(my_df) == length(c(id_cols, cols))+1){
    my_df = st_drop_geometry(my_df) }
  # convert data columns into a matrix
  my_mtrx = as.matrix(my_df %>% select(all_of(cols)))
  my_mtrx[is.na(my_mtrx)] = na_replace # fill na values
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

# row wise product of certain columns
column_product <- function(my_df, cols, id_cols=c(), na_replace=1){
  # subset the data into only what columns are needed
  my_df <- my_df %>% select(all_of(c(id_cols, cols)))
  # if my_df is a sf dataframe it will retain the extra geom. column
  if(ncol(my_df) == length(c(id_cols, cols))+1){
    my_df = st_drop_geometry(my_df) }
  # replace NAs with 1 in the dataframe
  my_df = my_df %>% 
    mutate(across(all_of(cols), ~replace(., is.na(.), na_replace)))
  # calculate rowwise product of the values
  my_df = my_df %>%
    rowwise() %>%
    mutate(vals = prod(c_across(cols)))
  # return output values
  if(length(id_cols)==0){return(my_df$vals)
  }else{  # if id columns given return dataframe with id columns
    my_df = my_df %>% select(all_of(c(id_cols, "vals")))
    return(my_df) }
}

###
# create output filename for a model object and type of object
object_filename <- function(object, type_tag, suffix=".gpkg", subfolder="intermediate_data"){
  ### examples of type tags
  # constr = constraints
  # lyrext = layer extraction
  # lyrcmb = combined layer
  # submdl = submodel (with scored layer values)
  # mdlout + final model output (with submodel values)
  
  # get root of filepath that will be true for any object
  fp_out = file.path(sub("/$", "", project_dir), subfolder, paste(c(region_code, project_code, file_tags), collapse="_"))
  # get date
  date = format(Sys.Date(), "%Y%m%d")
  # create full filepath
  fp_out = paste(c(fp_out, type_tag, object$name, date), collapse="_")
  # add suffix
  fp_out = paste0(fp_out, suffix)
  return(fp_out)
}

###

# from input settings contained in a layer run a loading function and 
 # a scoring function and return the values (with the id columns)
load_and_score_model_layer <- function(layer_object, write_fp=NULL){
  # get lists to map string inputs to functions 
  extraction_functions <- list(
    "raster" = load_raster_values,
    "polygon_intersection" = load_polygon_intersection_boolean,
    "polygon_value" = load_polygon_intersection_value,
    "scored_hex" = load_scored_hex_grid )
  
  membership_functions <- list(
    "z_mem" = z_membership,
    "s_mem" = s_membership,
    "linear" = linear_membership,
    "quantile" = quantile_membership,
    "binned" = bin_membership,
    "mapped" = mapped_membership,
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
  hex_values[[layer_object$name]] = do.call(
    membership_functions[[layer_object$mem_fun]],
    args = args_list )
  ### save if required
  if(save_extractions){write.csv(hex_values, object_filename(layer_object, "lyrext", suffix=".csv"), row.names=FALSE)}
  # return
  return(hex_values %>% select(-vals))
}

###

# iteratively load and score the contained layers and then calculate
 # the combined layer
calculate_combined_layer <- function(layer_object, fill_value=1){
  # functions for combining layers
  combine_functions <- list(
    "product" = column_product,
    "geom_mean" = geom_mean_columns)
  
  # get hex grid and id_cols from global variable
  id_cols = get(layer_object$id_cols_var)
  hex_sf = get(layer_object$hex_grid_var) %>%
    st_drop_geometry(.) %>%
    select(all_of(id_cols))
  
  # get each model layer extracted
  weights = c()
  for(kk in seq(length(layer_object$score_params$layers))){
    hex_sf = hex_sf %>% 
      left_join(load_and_score_model_layer(layer_object$score_params$layers[[kk]]),
                by = id_cols)
    weights = c(weights, layer_object$score_params$layers[[kk]]$weight)
  }
  # get column names to take the product of
  cols = colnames(hex_sf %>% select(-all_of(id_cols)))
  ### run the relevant combination function
  # standard parameters
  args_list = list(my_df=hex_sf, cols=cols, id_cols=id_cols, na_replace=fill_value)
  # if geom mean add weights as a parameter
  if(layer_object$mem_fun=="geom_meam"){args_list[["weights"]] = weights}
  # run combine
  hex_values = do.call(combine_functions[[layer_object$mem_fun]], args = args_list )
  # rename
  hex_values = hex_values %>%
    rename(!!layer_object$name := "vals")
  ### save if required
  if(save_extractions){
    hex_sf$vals = hex_values[[layer_object$name]]
    write.csv(hex_sf, object_filename(layer_object, "lyrcmb", suffix=".csv"), row.names=FALSE)}
  ###
  # return
  return(hex_values)
}

###

# from a submodel object, load the layers as columns and calculate 
 # the final submodel value
calculate_submodel <- function(submodel_object){
  if(verbose>4){print(paste("Submodel started:",submodel_object$name, Sys.time()))}
  # get # of layers in submodel
  n_lyrs = length(submodel_object$layers)
  # get hex grid and id_cols from global variable
  id_cols = get(submodel_object$id_cols_var)
  sm_hex_df = get(submodel_object$hex_grid_var) %>%
    st_drop_geometry(.) %>%
    select(all_of(id_cols))
  # load each submodel layer into data frame
  lyr_names = c()
  for(jj in seq(n_lyrs)){
    lyr = submodel_object$layers[[jj]] # get layer object
    if(verbose>7){print(paste("Layer started:",lyr$name, Sys.time()))}
    ### load and score the layer object
    # if a combined layer
    if(lyr$input_type=="combined"){
      lyr_data = calculate_combined_layer(lyr)
    # if not a combined layer
    }else{ lyr_data = load_and_score_model_layer(lyr) }
    # add layer data onto empty hex object
    sm_hex_df = left_join(sm_hex_df, lyr_data, by=id_cols)
    # keep name of the layers
    lyr_names = c(lyr_names, lyr$name)
    if(verbose>7){print(paste("Layer finished:",lyr$name, Sys.time()))}
  }
  # calculate weighted geom mean of submodel layers
  sm_vals = geom_mean_columns(my_df=sm_hex_df,
                              cols=lyr_names, id_cols=id_cols, weights=submodel_object$weights)
  # rejoin values to the hex and name the column to the submodel name
  sm_hex_df = left_join(sm_hex_df,
                        sm_vals %>% rename(!!submodel_object$name := vals),
                        by=id_cols )
  # return
  if(verbose>4){print(paste("Submodel finished:",submodel_object$name, Sys.time()))}
  return(sm_hex_df)
}

###

# run model object, run calculate submodel 1 by 1 and then
 # calculate the final model value
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
  for(ii in seq(n_sms)){
    # get the submodel object
    sm_obj = full_model_object$submodels[[ii]]
    # load and score the submodel object
    sm_data = calculate_submodel(sm_obj)
    ### Save submodel if needed to be saved
    if(save_submodels){st_write(get(full_model_object$hex_grid_var) %>% left_join(sm_data, by=id_cols),
                                object_filename(sm_obj, "submdl"), append=FALSE, delete_layer=TRUE) }
    ###
    # add sm data onto empty hex object
    fm_hex_df = left_join(fm_hex_df,
                          sm_data %>% select(all_of(c(id_cols, sm_obj$name))),
                          by=id_cols)
    # keep name of the layers
    sm_names = c(sm_names, c(sm_obj$name))
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

###

# identify which layers go into combined layers and return info on each 
 # layer to send them to the correct destination
group_and_index_model_layers <- function(model_layers){
  # initialize data frame to track model layer information
  layer_info <- data.frame(indx=integer(), name = character(), group = character(),
                           weight = integer(),type = character())
  # iterate through model layers and track the layer info
  for(i in seq(length(model_layers))){
    lyr = model_layers[[i]]
    layer_info[i,c(2,3,5)] = c(lyr$name, lyr$destination, lyr$input_type)
    layer_info[i,c(1,4)]   = c(i, lyr$weight)
  }
  ### remove layers in combined layers and add them to the relevant combined layers
  combined_layers = layer_info %>% filter(type=="combined") # combined layers
  rm_indxs = c() # track indexes to remove
  if(nrow(combined_layers)>0){
    for(j in seq(nrow(combined_layers))){
      # get which layers are relevant to the current combined layer
      group_layers = layer_info$indx[layer_info$group==combined_layers$name[j]]
      # add layer objects for the combined layer to the combined layer
      model_layers[[combined_layers$indx[j]]]$score_params = c(
        model_layers[[combined_layers$indx[j]]]$score_params, list(layers=model_layers[group_layers]))
      rm_indxs = c(rm_indxs, group_layers)
    }
    layer_info = layer_info %>%
      filter(!(indx %in% rm_indxs))
  }
  return(list(model_layers, layer_info))
}

###

# go through the submodels and create submodel objects and then put them into
 # a nested full model object
create_fullmodel_object <- function(model_layers, layer_info, submodel_names, submodel_weights, model_name){
  if(length(unique(layer_info$group)) != length(submodel_names)){print("ERROR: SUBMODEL AND DESTINATION LENGTHS DON'T MATCH")}
  
  # iterate through submodels and create submodel objects
  submodel_objects = list()
  for(i in seq(length(submodel_names))){
    submodel_objects[[i]] = list(
      name = submodel_names[i],
      layers = model_layers[layer_info$indx[layer_info$group==submodel_names[i]]],
      hex_grid_var = "hex_grid_global",
      id_cols_var = "id_cols_global"
    )
  }
  # 
  full_model_object = list(
    name = model_name,
    submodels = submodel_objects,
    weights = submodel_weights,
    hex_grid_var = "hex_grid_global",
    id_cols_var = "id_cols_global"
  )
  #
  return(full_model_object)
}

###





