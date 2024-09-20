library(matrixStats)
library(dplyr)

# calculate weighted geometric means of columns in a dataframe
geom_mean_columns <- function(my_df, cols, id_cols=c(), weights=NULL){
  # subset the data into only what columns are needed
  my_df <- my_df %>% select(all_of(c(id_cols, cols)))
  # if my_df is a sf dataframe it will retain the extra geom. column
  if(ncol(my_df) == length(c(id_cols, cols))+1){
    my_df = st_drop_geometry(my_df) }
  # convert data columns into a matrix
  my_mtrx = as.matrix(my_df %>% select(all_of(cols)))
  # initialize even weighting if none given
  if(is.null(weights)){ weights = rep(1/ncol(my_mtrx), ncol(my_mtrx)) }
  ### run rowwise weighted mean calculation by using matrix math
  # transpose the matrix and take the columwise exponent based on the weights
  # then transpose back to the original format
  my_mtrx = t(t(my_mtrx)^weights)
  # get product of row values and raise to the power of 1/ the sum of the weights
  vals = matrixStats::rowProds(my_mtrx)^(1/sum(weights))
  # return output values
  if(length(id_cols)==0){return(vals)
  }else{  # if id columns given return dataframe with id columns
    my_df = my_df %>% select(all_of(id_cols))
    my_df$vals = vals
    return(my_df)
  }
}

###



