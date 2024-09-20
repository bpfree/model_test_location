
library(dplyr)
library(ggplot2)
library(sf)
library(terra)

# possible methods: "mean", "max", "min", "sum", "weighted_mean'
extract_polygon_intersection_value <- function(poly_extr, fp_poly_in, value_col,
                                               id_cols=c(), layer=NULL, method="mean"){
  # make list of functions 
  funcs_list_narm = list("mean"=mean, "min"=min, "max"=max, "median"=median)
  funcs_list_else = list("first"=first)
  # make sure input polygon is a sf
  poly_extr = st_as_sf(poly_extr) %>% select(all_of(id_cols))
  # read the input polygon file
  if(is.null(layer)){ my_sf = st_read(fp_poly_in, quiet=TRUE)
  }else{ my_sf = st_read(dsn=fp_poly_in, layer=layer, quiet = TRUE) }
  # project to crs of the extraction polygon
  my_sf = st_transform(my_sf, st_crs(poly_extr))
  # get just the target column
  my_sf = my_sf %>% select(value_col)
  # get the extraction polygon (grid) that intersects the input polygon
  extraction = st_intersection(poly_extr, my_sf)
  # summarise to return one value per extraction feature
  extraction = extraction %>%
    st_drop_geometry(.) %>%
    group_by(GRID_ID, study_area) %>%       # FIX THIS WITH INTERENT TO LOOK UP
    summarise(
      vals = ifelse(method %in% names(funcs_list_narm),
                    funcs_list_narm[[method]](get(value_col), na.rm=TRUE),
                    funcs_list_else[[method]](get(value_col)) )
    )
  # return
  return(extraction)
}





a = st_read("./data/test_grid_ak.gpkg")
a = a[1:100,]

b = "C:/Users/Isaac/Downloads/Clipped_WetlandsII-20240917T191030Z-001/Clipped_WetlandsII/Clipped_WetlandsII.shp"
# b = "C:/Users/Isaac/Downloads/statistical_areas.gpkg"
# b = "./data/test_rast_ak.tif"

# c = "PVB_CF_salmon_statewide_2024_NAD83_subset"
c=NULL

d = "WETLAND_TY"
# d = "ACRES"

test_out = extract_polygon_intersection_value(poly_extr = a, fp_poly_in = b, layer=c, value_col=d,
                                 id_cols=c("GRID_ID", "study_area"), method="first")



