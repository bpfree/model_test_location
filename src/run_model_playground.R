

library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")
source("./src/model_functions.R")
verbose <<- 10

# define the settings file
input_file_global <<- "test_model_run.csv"

# parse the settings file into model architecture variables
source("./src/parse_inputFile.R")

# define the hex grid for the model run
hex_grid_global <<- st_read(file.path(sub("/$", "", source_dir), hex_grid_global_path)) %>%  # in this case it's in the source dir, might not be though
  select(all_of(id_cols_global))

# group and index the model layers 
temp <- group_and_index_model_layers(model_layers)
model_layers = temp[[1]]
layer_info = temp[[2]]

# create submodel objects and nest them into a full model object
full_model_object <- create_fullmodel_object(model_layers, layer_info, submodel_names, submodel_weights, model_name)

# run the model calulcation on the model object
out_df = calculate_model(full_model_object)

# save the output
st_write(hex_grid_global %>% left_join(out_df, by=id_cols_global),
         object_filename(full_model_object, "mdlout"),
         delete_layer=TRUE, append=FALSE)

