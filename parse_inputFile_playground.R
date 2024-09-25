
library(readr)
library(dplyr)


file_input = read.csv("test_model_run.csv", stringsAsFactors = FALSE)


global_input = file_input[file_input[[1]]=="Global",]
layer_input = file_input[file_input[[1]]=="Layer",]
fullmodel_input = file_input[file_input[[1]]=="Model",]

##############################
### Parse global variables
# standard hex grid and id columns
hex_grid_global <<- global_input[global_input[[2]]=="hex grid", 3]
id_cols_global <<- global_input[global_input[[2]]=="id columns", 3:ncol(global_input)]
id_cols_global <<- id_cols_global[id_cols_global!=""]
# assign other variables
global_params = global_input[!(global_input[[2]] %in% c("hex grid", "id columns")),]
for(n in seq(nrow(global_params))){
  p_val = global_params[n,3:ncol(global_params)]
  p_val = p_val[p_val!=""]
  if(length(p_val)==1){p_val = p_val[1]}
  assign(global_params[n,2], parse_guess(p_val))
}


###############################
### parse full model settings
if(nrow(fullmodel_input)>2){print("ERROR: TOO MANY MODEL SETTINGS ROWS")}
# model name
model_name <- fullmodel_input[1,2]
# submodel names
submodel_names <- fullmodel_input[fullmodel_input[[3]]=="submodel_names",4:ncol(fullmodel_input)]
submodel_names = submodel_names[!submodel_names==""]
# submodel weights
submodel_weights <- fullmodel_input[fullmodel_input[[3]]=="submodel_weights",4:ncol(fullmodel_input)]
submodel_weights = submodel_weights[submodel_weights!=""]
submodel_weights = as.double(submodel_weights)
##############################