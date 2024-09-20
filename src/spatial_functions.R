
library(sf)
library(terra)
library(dplyr)

# extract values from a raster onto the hex grid
  # possible methods: "mean", "max", "min", "sum", "weighted_mean"
extract_raster_values <- function(poly_extr, fp_ras_in, id_cols=c(), method="mean", band=1){
  # terra as weird, this makes sure the input works whether sf or spatVect
  poly_extr = vect(st_as_sf(poly_extr) %>% select(all_of(id_cols)))
  # read the raster file
  my_ras = rast(fp_ras_in, lyrs=band)
  my_ras = project(my_ras, crs(poly_extr))
  # extract the raster values, weighted mean
  if(method=="weighted_mean"){
    extraction = terra::extract(my_ras, poly_extr, fun="mean", bind=TRUE, weights=TRUE, na.rm=TRUE)
  }else{
    extraction = terra::extract(my_ras, poly_extr, fun=method, bind=TRUE, weights=FALSE, na.rm=TRUE) }
  # convert to sf and rename column to vals
  extraction = st_as_sf(extraction) %>%
    st_drop_geometry(.) %>%
    rename(vals = names(my_ras)[1])
  # return
  return(extraction)
}

###

# extract if input polygon (hex grid) intersects an input polygon filepath
extract_polygon_intersection_boolean <- function(poly_extr, fp_poly_in, id_cols=c(), layer=NULL){
  # make sure hex grid is an sf
  poly_extr = st_as_sf(poly_extr) %>% select(all_of(id_cols))
  # read the input polygon file
  if(is.null(layer)){ my_sf = st_read(fp_poly_in, quiet=TRUE)
  }else{ my_sf = st_read(dsn=fp_poly_in, layer=layer, quiet = TRUE) }
  # project to crs of the extraction polygon
  my_sf = st_transform(my_sf, st_crs(poly_extr))
  # get the extraction polygon (grid) that intersects the input polygon
  extraction = st_intersects(poly_extr, my_sf, sparse=TRUE)
  #get true/ false column if length of intersects > 0
  poly_extr$vals = as.numeric(lapply(extraction, length)>0)
  # return
  return(st_drop_geometry(poly_extr))
}

###

# extract value from a target field in a polygon layer, summarizing if multiple intersections
  # possible methods: "mean", "max", "min", "sum", "median", "first"
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

###







