
library(readr)
library(dplyr)
library(stringr)

file_input = read.csv(input_file_global, stringsAsFactors = FALSE)

global_input = file_input[file_input[[1]]=="Global",]
layer_input = file_input[file_input[[1]]=="Layer",]
fullmodel_input = file_input[file_input[[1]]=="Model",]

##############################
### Parse global variables
# standard hex grid and id columns
hex_grid_global_path <<- global_input[global_input[[2]]=="hex grid", 3]
id_cols_global <<- global_input[global_input[[2]]=="id columns", 3:ncol(global_input)]
id_cols_global <<- id_cols_global[id_cols_global!=""]
# assign other variables
global_params = global_input[!(global_input[[2]] %in% c("hex grid", "id columns", "constraints")),]
for(n in seq(nrow(global_params))){
  p_val = global_params[n,3:ncol(global_params)]
  p_val = p_val[p_val!=""]
  if(length(p_val)==1){p_val = p_val[1]}
  assign(global_params[n,2], parse_guess(p_val))
}
## assign hex grid filtering
hex_load_params = list("fp_in"=hex_grid_global_path, "id_cols"=id_cols_global,
                       "value_col"=NULL, "values"=NULL)
temp = global_input[global_input[[2]]=="hex grid", 4:ncol(global_input)]
temp = temp[temp!=""]
if(length(temp)>0){
  for(g in seq(length(temp))){
    entry = temp[[g]]
    # split based on the equals sign
    entry = unlist(str_split(entry, "="))
    entry[[1]] = sub(" ", "", entry[[1]]) # remove any spaces from the variable name
    # if the variable value item has commas, define the param as a vector of the items
    if(any(grep(",", entry[2]))){
      items = parse_guess(unlist(str_split(entry[2], ","))) # split and parse
      hex_load_params[[entry[1]]] <- items # add to hex grid filter list
    }else{hex_load_params[[entry[1]]] <- parse_guess(entry[2])} # if no comma separating items add the parameter directly
  } # g loop
} # if length temp
## assign constraints variables
constr_global <<- list()
if(any(global_input[,2]=="constraints")){
  constr_global["fp_in"] = global_input[global_input[[2]]=="constraints",3]
  entry = global_input[global_input[[2]]=="constraints", 4:ncol(global_input)]
  entry = unlist(str_split(entry[entry!=""], "="))
  entry[[1]] = sub(" ", "", entry[[1]])
  constr_global[entry[[1]]] = entry[[2]]
} # if any constraints

###############################
### parse full model settings
if(nrow(fullmodel_input)>2){print("ERROR: TOO MANY MODEL SETTINGS ROWS")}
# model name
model_name <- fullmodel_input[1,2]
# submodel names
submodel_names <- fullmodel_input[fullmodel_input[[3]]=="submodel_names",4:ncol(fullmodel_input)]
submodel_names <<- submodel_names[!submodel_names==""]
# submodel weights
submodel_weights <- fullmodel_input[fullmodel_input[[3]]=="submodel_weights",4:ncol(fullmodel_input)]
submodel_weights <- submodel_weights[submodel_weights!=""]
submodel_weights <<- as.double(submodel_weights)

#############################
### Parse layer objects
# set up layer inputs dataframe
layer_input = layer_input[,-1]
colnames(layer_input)[1:6] = c("name", "destination", "weight", "fp_in", "type", "mem_fun")

model_layers = list() # empty model layers list
# 
for(n in seq(nrow(layer_input))){
  # get current row
  layer_row = layer_input[n,]
  ######
  # get load and score parameters
  load_params_raw = layer_row[which(layer_row=="load_params"):which(layer_row=="score_params")]
  score_params_raw = layer_row[which(layer_row=="score_params"):ncol(layer_input)]
  # get only real values
  load_params_raw = load_params_raw[!(load_params_raw %in% c("load_params", "score_params", ""))]
  score_params_raw = score_params_raw[!(score_params_raw %in% c("load_params", "score_params", ""))]
  ###
  # extract each load parameter
  load_params = list()
  # only iterate if there are things to extract
  if(length(load_params_raw)>0){
    for(l in seq(length(load_params_raw))){
      entry = load_params_raw[[l]]
      # split based on the equals sign
      entry = unlist(str_split(entry, "="))
      entry[[1]] = sub(" ", "", entry[[1]]) # remove any spaces from the variable name
      # if the variable value item has commas, define the param as a vector of the items
      if(any(grep(",", entry[2]))){
        items = parse_guess(unlist(str_split(entry[2], ","))) # split and parse
        load_params[[entry[1]]] <- items # add to parameters list
      }else{load_params[[entry[1]]] <- parse_guess(entry[2])} # if no comma seperating items add the parameter directly
    } # l load params loop
  } # if length load > 0
  ### 
  # extract each score parameter
  score_params = list()
  # only iterate if there are things to extract
  if(length(score_params_raw)>0){
    for(s in seq(length(score_params_raw))){
      entry = score_params_raw[[s]]
      # split based on the equals sign
      entry = unlist(str_split(entry, "="))
      entry[[1]] = sub(" ", "", entry[[1]]) # remove any spaces from the variable name 
      # if the variable value item has commas, define the param as a vector of the items
      if(any(grep(",", entry[2]))){
        items = parse_guess(unlist(str_split(entry[2], ","))) # split and parse
        score_params[[entry[1]]] <- items # add to parameters list
      }else{score_params[[entry[1]]] <- parse_guess(entry[2])} # if no comma seperating items add the parameter directly
    } # s score params loop
  } # if score length > 0
  ###########################################################
  ### initialize layer object and then add to model_layers
  lyr = list(
    name = layer_row$name,
    destination = layer_row$destination,
    fp_data_in = file.path(sub("/$", "", source_dir), layer_row$fp_in),
    input_type = layer_row$type,
    mem_fun = layer_row$mem_fun,
    load_params = load_params,
    score_params = score_params,
    hex_grid_var = "hex_grid_global",
    id_cols_var = "id_cols_global",
    weight = parse_guess(layer_row$weight)
  )
  # add to model_layers
  model_layers[[n]] = lyr
} # n layer_input loop


###
# make sure output folder exists
dir.create(file.path(sub("/$", "", project_dir), "intermediate_data"), showWarnings = FALSE)

































