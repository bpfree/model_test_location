
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
  fp_data_in = "./data/ak_polygon_juneau_test.gpkg",
  destination = "submodel_1",
  input_type = "polygon_intersection",
  mem_fun = "mapped_membership",
  load_params = list(),
  score_params = list("values" = c(1), "targets"=c(0.25)),
  hex_grid_var = "hex_grid_global",
  id_cols_var = "id_cols_global",
  weight = 1
)

##

layer_4 = list(
  layer_name = "wet_clip_tst",
  fp_data_in = "./data/test_nwi_poly.shp",
  destination = "submodel_2",    
  input_type = "polygon_value",
  mem_fun = "linear_membership",
  load_params = list("value_col" = "ACRES"),
  score_params = list(out_range=c(0.3,0.7)),
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



