
library(dplyr)
library(ggplot2)
library(sf)
library(terra)
source("./src/spatial_functions.R")
source("./src/membership_functions.R")



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




test_plot = ggplot(hex_values) +
  theme_bw() +
  geom_point(aes(x=vals, y=depth))


