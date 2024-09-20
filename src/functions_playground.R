
library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")


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
  my_sf = get(layer_object$hex_grid_var) %>%
    select(all_of(id_cols))

  
  # load in the data
  my_sf = extraction_functions[[layer_object$input_type]](
    poly_extr=my_sf, fp_in=layer_object$fp_data_in, id_cols=id_cols
    # layer_object$load_params                                            # NEED TO FIGURE OUT HOW TO SEND ARGS IN FROM LIST
  )
  
  # score the layer
  my_sf[[layer_object$layer_name]] = membership_functions[[layer_object$mem_fun]](
    x = my_sf$vals
  )
  
  # return
  my_sf = st_drop_geometry(my_sf) %>%
    select(all_of(c(id_cols, layer_object$layer_name)))
  return(my_sf)
}





a = st_read("./data/test_grid_ak.gpkg")
a = a[1:150,]

# b = "C:/Users/Isaac/Downloads/Clipped_WetlandsII-20240917T191030Z-001/Clipped_WetlandsII/Clipped_WetlandsII.shp"
# b = "C:/Users/Isaac/Downloads/statistical_areas.gpkg"
# b = "./data/test_rast_ak.tif"
b = "./data/test_scored_hex.gpkg"

# c = "PVB_CF_salmon_statewide_2024_NAD83_subset"
# c=NULL
c = "test_scored_hex"

# d = "WETLAND_TY"
# d = "ACRES"
d = "dummy"

test_out = extract_scored_hex_grid(poly_extr = a, fp_hex_in = b, value_col=d, layer=c,
                                 id_cols=c("GRID_ID", "study_area"))



