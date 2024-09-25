
source("./src/membership_functions.R")
source("./src/model_functions.R")
source("./src/spatial_functions.R")

hex_grid_global <<- st_read("./data/test_grid_ak_small.gpkg")
id_cols_global <<- c("GRID_ID", "study_area")

##

layer_1 = list(
  layer_name = "depth",
  destination = "submodel_1",
  fp_data_in = "./data/test_rast_ak.tif",
  input_type = "raster",
  mem_fun = "s_membership",
  load_params = list("method"="mean", "band"=1),
  score_params = list("upper_clamp" = "max", "lower_clamp" = "min",
                      "zero_offset"=(1/1000), "out_range"="default"),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)

##

layer_2 = list(
  layer_name = "score_tst",
  destination = "test_comb",
  fp_data_in = "./data/test_scored_hex.gpkg",
  input_type = "scored_hex",
  mem_fun = "none",
  load_params = list("value_col"="dummy"),
  score_params = list(),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)

##

layer_3 = list(
  layer_name = "st_area_tst",
  fp_data_in = "C:/Users/Isaac/Downloads/statistical_areas.gpkg",
  destination = "submodel_1",
  input_type = "polygon_intersection",
  mem_fun = "mapped_membership",
  load_params = list("layer" = "PVB_CF_salmon_statewide_2024_NAD83_subset"),
  score_params = list("values" = c(1), "targets"=c(0.25)),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)

##

layer_4 = list(
  layer_name = "wet_clip_tst",
  fp_data_in = "C:/Users/Isaac/Downloads/Clipped_WetlandsII-20240917T191030Z-001/Clipped_WetlandsII/Clipped_WetlandsII.shp",
  destination = "submodel_2",    
  input_type = "polygon_value",
  mem_fun = "linear_membership",
  load_params = list("value_col" = "ACRES"),
  score_params = list(),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)

#

layer_5 = list(
  layer_name = "score_tst1",
  fp_data_in = "./data/test_scored_hex.gpkg",
  destination = "test_comb",
  input_type = "scored_hex",
  mem_fun = "linear_membership",
  load_params = list("value_col"="r_val", "layer"="test_val"),
  score_params = list(),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)

#

layer_comb = list(
  layer_name = "test_comb",
  fp_data_in = NULL,
  destination = "submodel_2",
  input_type = "combined",
  mem_fun = "product",
  load_params = list(),
  score_params = list(),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)




############################################
model_layers = list(layer_1, layer_2, layer_3, layer_4, layer_5, layer_comb)


##############################################

submodel_1 = list(
  name = "submodel_1",
  layers = list(layer_1, layer_2),
  weights = c(1,1),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global"
)

submodel_2 = list(
  name = "submodel_2",
  layers = list(layer_3, layer_4),
  weights = c(1,1),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global"
)

##############################################

model_1 = list(
  name = "model_1",
  submodels = list(submodel_1, submodel_2),
  weights = c(1, 1),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global"
)






dummy = load_and_score_model_layer(layer_5)
dummy = load_and_score_model_layer(layer_2)



submodel_names = c("submodel_1", "submodel_2")
submodel_weights = c(1,2)






