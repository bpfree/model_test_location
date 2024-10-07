
library(dplyr)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")
source("./src/model_functions.R")
verbose <<- 10

# define the settings file
#   * needs to be set for the model run
input_file_global <<- "test_model_run.csv"

#########################################################
###### AUTOMATIC MODEL RUNNING

# parse the settings file into model architecture variables
source("./src/parse_input_file.R")

# load the hex grid for the model run
hex_grid_global <<- do.call(load_empty_hex_grid, args = hex_load_params)


# filter hex grid based on the constraints
if(length(constr_global)>0){ hex_grid_global <<- apply_model_constraints(
  hex_sf=hex_grid_global, constr_object=constr_global, id_cols=id_cols_global) }

# group and index the model layers 
temp <- group_and_index_model_layers(model_layers)
model_layers = temp[[1]]
layer_info = temp[[2]]

# create submodel objects and nest them into a full model object
full_model_object <- create_fullmodel_object(model_layers, layer_info, submodel_names, submodel_weights, model_name)

# run the model calulcation on the model object
if(verbose>0){print(paste("Model started:",full_model_object$name, Sys.time()))}
out_df = calculate_model(full_model_object)

##### save the output
## get final output sf dataframe object to save
# if constrained rejoin to original hex
if(length(constr_global)>0){hex_grid_global <<- do.call(load_empty_hex_grid, args = hex_load_params)}
out_hex = hex_grid_global %>%
  left_join(out_df, by=id_cols_global) %>%
  mutate(across(colnames(out_df %>% select(-all_of(id_cols_global))),
                ~replace(., is.na(.), 0)))
## write full model output
st_write(out_hex,
         object_filename(full_model_object, "mdlout"),
         delete_layer=TRUE, append=FALSE, quiet = TRUE)

if(verbose>0){print(paste("Model finished:",full_model_object$name, Sys.time()))}
