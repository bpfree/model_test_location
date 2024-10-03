
library(sf)
library(terra)
library(dplyr)

# extract values from a raster onto the hex grid
  # possible methods: "mean", "max", "min", "sum", "weighted_mean"
load_raster_values <- function(poly_extr, fp_in, id_cols=c(), method="mean", band=1){
  # terra as weird, this makes sure the input works whether sf or spatVect
  poly_extr = vect(st_as_sf(poly_extr) %>% select(all_of(id_cols)))
  # read the raster file
  my_ras = rast(fp_in, lyrs=band)
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
load_polygon_intersection_boolean <- function(poly_extr, fp_in, id_cols=c(),
                                              layer=NULL, buffer=NULL){
  # make sure hex grid is an sf
  poly_extr = st_as_sf(poly_extr) %>% select(all_of(id_cols))
  st_agr(poly_extr) = "constant" # set constant relationship between attributes and geometry
  # read the input polygon file
  if(is.null(layer)){ my_sf = st_read(fp_in, quiet=TRUE)
  }else{ my_sf = st_read(dsn=fp_in, layer=layer, quiet = TRUE) }
  st_agr(my_sf) = "constant" # set constant relationship between attributes and geometry
  # project to crs of the extraction polygon
  my_sf = st_transform(my_sf, st_crs(poly_extr))
  # apply buffer if present
  if(!is.null(buffer)){ my_sf = st_buffer(my_sf, dist=buffer)}
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
load_polygon_intersection_value <- function(poly_extr, fp_in, value_col, id_cols=c(),
                                            layer=NULL, method="mean", buffer=NULL){
  # make list of functions 
  funcs_list_narm = list("mean"=mean, "min"=min, "max"=max, "median"=median)
  funcs_list_else = list("first"=first)
  # make sure input polygon is a sf
  poly_extr = st_as_sf(poly_extr) %>% select(all_of(id_cols))
  st_agr(poly_extr) = "constant" # set constant relationship between attributes and geometry
  # read the input polygon file
  if(is.null(layer)){ my_sf = st_read(fp_in, quiet=TRUE)
  }else{ my_sf = st_read(dsn=fp_in, layer=layer, quiet = TRUE) }
  st_agr(my_sf) = "constant" # set constant relationship between attributes and geometry
  # project to crs of the extraction polygon
  my_sf = st_transform(my_sf, st_crs(poly_extr))
  # get just the target column
  my_sf = my_sf %>% select(all_of(value_col))
  # apply buffer if present
  if(!is.null(buffer)){ my_sf = st_buffer(my_sf, dist=buffer)}
  # get the extraction polygon (grid) that intersects the input polygon
  extraction = st_intersection(poly_extr, my_sf)
  # summarise to return one value per extraction feature
  extraction = extraction %>%
    st_drop_geometry(.) %>%
    group_by_at(id_cols) %>%       
    summarise(
      vals = ifelse(method %in% names(funcs_list_narm),
                    funcs_list_narm[[method]](get(value_col), na.rm=TRUE),
                    funcs_list_else[[method]](get(value_col)) ),
    .groups = "drop")
  # return
  return(extraction)
}

###

# extract already scored column on a hex grid with the id columns present
load_scored_hex_grid <- function(poly_extr, fp_in, value_col,
                                    id_cols=c(), layer=NULL){
  # make sure input polygon is a sf
  poly_extr = st_as_sf(poly_extr) %>%
    select(all_of(id_cols)) %>%
    st_drop_geometry(.)
  # read the input polygon file
  if(is.null(layer)){ my_sf = st_read(fp_in, quiet=TRUE)
  }else{ my_sf = st_read(dsn=fp_in, layer=layer, quiet = TRUE) }
  st_agr(my_sf) = "constant" # set constant relationship between attributes and geometry
  # get just the target column
  my_sf = my_sf %>% 
    st_drop_geometry(.) %>%
    select(all_of(c(id_cols, value_col))) %>%
    rename(vals = !!as.symbol(value_col))
  # get the extraction of the two by column id
  poly_extr = poly_extr %>%
    left_join(my_sf, by=id_cols)
  # return
  return(poly_extr)
}

###

# load a hex grid from a filepath and filter it based on a column and values
load_empty_hex_grid <- function(fp_in, id_cols, value_col=NULL, values=NULL){
  hex_sf <- st_read(fp_in, quiet=TRUE) %>%
    select(all_of(unique(c(id_cols, value_col))))
  if(!is.null(value_col)){
    hex_sf = hex_sf %>%
      filter(!!as.symbol(value_col) %in% values) }
  st_agr(hex_sf) = "constant" # set constant relationship between attributes and geometry
  return(hex_sf)
}

###


