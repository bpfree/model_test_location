

hex_grid_global = st_read("./data/test_grid_ak.gpkg")[1:150,]
id_cols_global = c("GRID_ID", "study_area")

layer_1 = list(
layer_name = "depth",
fp_data_in = "./data/test_rast_ak.tif",
input_type = "raster",
mem_fun = "s_membership",
load_params = list("method"="mean", "band"=1),
score_params = list(upper_clamp = "max", lower_clamp = "min",
                    zero_offset=(1/1000), out_range="default"),
hex_grid_var = "hex_grid_global",
id_cols_var = "id_cols_global"
)

layer_2 = list(
  layer_name = "depth",
  fp_data_in = "./data/test_scored_hex.gpkg",
  input_type = "scored_hex",
  mem_fun = "none",
  load_params = list("value_col"="dummy"),
  score_params = list(),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global"
)



layer_object <- function(){
  
  
}




