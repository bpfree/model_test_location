
# returns a vector Z-membership of rescaled values from a vector input of number values
z_membership <- function(x, upper_clamp = "max", lower_clamp = "min",
                           zero_offset=(1/1000), out_range="default"){
  # get the upper clamp value from the input either taking the max or setting the value
  upper_clamp = ifelse(upper_clamp=="max", max(x, na.rm=TRUE), upper_clamp)
  # set the min and max values needed for the reduction equation.
  #Max gets the zero offset so that values don't equal 0.
  z_max = (upper_clamp + (upper_clamp*zero_offset))
  z_min = ifelse(lower_clamp=="min", min(x, na.rm=TRUE), lower_clamp)
  # clamp values above upper bound to the upper limit
  x = ifelse(x > upper_clamp, upper_clamp, x) 
  
  # calculate z-scores (more desired values get score of 1 while less desired will decrease till ~0)
  z_value <- ifelse(x<=z_min, 1, # if value is equal to minimum, score as 1
                    # if value is larger than minimum but lower than mid-value, calculate based on reduction equation
                    ifelse(x>z_min & x<((z_min + z_max)/2), (1 - 2*((x-z_min) / (z_max-z_min))**2),
                           # if value is larger than mid-value, calculate based on equation. Values above max already clamped.
                           ifelse(x>=((z_min + z_max)/2), 2*(((x-z_max) / (z_max-z_min))**2), NA) ) )
  
  # if output range is given as upper and lower bounds, rescale output
  if(any(out_range != "default")){
    if(length(out_range)!=2){
      print("ERROR: BAD FORMAT OUTPUT RANGE MEM. FUNCTION")
      return() }
    z_value = z_value * ((out_range[2]-out_range[1])/(max(z_value, na.rm=TRUE)-min(z_value, na.rm=TRUE))) # multiply by range ratio
    z_value = z_value + (out_range[1] - min(z_value, na.rm=TRUE)) # shift left or right
  }
  
  return(z_value)
}
###

# returns a vector s-membership of rescaled values from a vector input of number values
s_membership <- function(x, upper_clamp = "max", lower_clamp = "min",
                           zero_offset=(1/1000), out_range="default"){
  # get the lower clamp value from the input either taking the max or setting the value
  lower_clamp = ifelse(lower_clamp=="min", min(x, na.rm=TRUE), lower_clamp)
  # set the min and max values needed for the reduction equation.
  #Max gets the zero offset so that values don't equal 0.
  s_min = (lower_clamp - (lower_clamp*zero_offset))
  s_max = ifelse(upper_clamp=="max", max(x, na.rm=TRUE), upper_clamp)
  # clamp values below lower bound to the lower limit
  x = ifelse(x < lower_clamp, lower_clamp, x) 
  
  # calculate s-scores (more desired values get score of 1 while less desired will decrease till ~0)
  s_value <- ifelse(x>=s_max, 1, # if value is greater than or equal to max, score as 1
                    # if value is larger than minimum but lower than mid-value, calculate based on reduction equation.
                    # Values below min are already clamped.
                    ifelse(x<((s_min + s_max)/2), 2*(((x-s_min) / (s_max-s_min))**2),
                           # if value is larger than mid-value, calculate based on equation. 
                           ifelse(x>=((s_min + s_max)/2) & x<s_max, (1 - 2*((x-s_max) / (s_max-s_min))**2), NA) ) )
  
  # if output range is given as upper and lower bounds, rescale output
  if(any(out_range != "default")){
    if(length(out_range)!=2){
      print("ERROR: BAD FORMAT OUTPUT RANGE MEM. FUNCTION")
      return() }
    s_value = s_value * ((out_range[2]-out_range[1])/(max(s_value, na.rm=TRUE)-min(s_value, na.rm=TRUE))) # multiply by range ratio
    s_value = s_value + (out_range[1] - min(s_value, na.rm=TRUE)) # shift left or right
  }
  
  return(s_value)
}
###

# negative relationship when rev=TRUE (default), positive-positive correlation when rev=FALSE
linear_membership <- function(x, rev=TRUE, upper_clamp = "max", lower_clamp = "min",
                              zero_offset=(1/1000), out_range="default"){
  
  # reverse order so larger values are smaller if desired
  if(rev){x = -1.0*x
  lower_clamp0 = lower_clamp
  lower_clamp = ifelse(upper_clamp=="max", "min", -1*upper_clamp) # swap upper and lower clamp values
  upper_clamp = ifelse(lower_clamp0=="min", "max", -1*lower_clamp0)}  # swap upper and lower clamp values
  
  # get clamp values from the input either taking the max or setting the value
  upper_clamp = ifelse(upper_clamp=="max", max(x, na.rm=TRUE), upper_clamp)
  lower_clamp = ifelse(lower_clamp=="min", min(x, na.rm=TRUE), lower_clamp)
  # clamp input values using the limits
  x = ifelse(x > upper_clamp, upper_clamp,
             ifelse(x < lower_clamp, lower_clamp, x)) 
  # set out_range to ~0 to 1 if default
  if(any(out_range=="default")){out_range=c(zero_offset, 1)}
  
  # linear rescale values, accounting for potential output range
  l_value = x * ((out_range[2]-out_range[1])/(upper_clamp-lower_clamp)) # multiply by range ratio
  l_value = l_value + (out_range[1] - min(l_value, na.rm=TRUE)) # shift left or right
  
  return(l_value)
}
###

# negative relationship when rev=TRUE (default), positive-positive correlation when rev=FALSE
quantile_membership <- function(x, nbins=9, rev=TRUE, targets="default",
                                quantiles=NULL, zero_offset=(1/1000)){
  
  # if no direct quantiles given set quantile breaks from nbins
  if(any(is.null(quantiles))){quantiles = seq(from=(1/nbins), by=(1/nbins), length.out=nbins-1)}
  # check for 1 more target values than quantile cutoffs
  if(any(targets!="default")){ if((length(targets)-length(quantiles))!=1){print("ERROR: QUANTILE VARIABLE LENGTHS DON'T MATCH")}}
  # get the default bin target values to map the quantile bins to
  if(any(targets=="default")){
    targets=seq(from=0,to=1,length.out=(length(quantiles)+1))
    targets[1] = zero_offset
    if(rev==TRUE){targets = rev(targets)}
    }
  # cut the input data into bins using the quantile breaks
  binned_x = cut(x, breaks=quantile(x, c(0, quantiles, 1)),
                 include.lowest = TRUE, labels = targets) 
  # convert factor outputs 
  binned_x = as.numeric(levels(binned_x))[binned_x]
  return(binned_x)
}
###

# negative relationship when rev=TRUE (default), positive-positive correlation when rev=FALSE
bin_membership <- function(x, nbins=9, rev=TRUE, targets="default",
                           breaks=NULL, zero_offset=(1/1000), fill_value=1){
  # if no direct bin mapping is given set breaks from nbins
  if(any(is.null(breaks))){breaks = seq(from=min(x, na.rm=TRUE), to=max(x, na.rm=TRUE), length.out=(nbins+1))}
  # check for 1 more target values than quantile cutoffs
  if(any(targets!="default")){if((length(breaks)-length(targets))!=1){print("ERROR: BIN VARIABLE LENGTHS DON'T MATCH")}}
  # get the default bin target values to map the quantile bins to
  if(any(targets=="default")){
    targets=seq(from=0,to=1,length.out=(length(breaks)-1))
    targets[1] = zero_offset
    if(rev==TRUE){targets = rev(targets)}
  }
  # cut the input data into bins using the quantile breaks
  binned_x = cut(x, breaks=breaks,
                 include.lowest = TRUE, labels = targets) 
  # convert factor outputs 
  binned_x = as.numeric(levels(binned_x))[binned_x]
  # replace NAs (outside bins) with fill_value
  binned_x[is.na(binned_x)]=fill_value
  return(binned_x)
}
###

# defaults to a positive-positive correlation, switch using rev=TRUE
mapped_membership <- function(x, values, targets, fill_value=1){
  # check for input
  if(length(values) != length(targets)){print("MAPPED MEM. VALUES TARGETS LENGTHS DON'T MATCH")}
  # created paired list of values 
  val_pairs = targets
  names(val_pairs) = values
  val_pairs = as.list(val_pairs)
  # remap values 
  mapped_x = ifelse(x %in% values,
                    val_pairs[as.character(x)],
                    fill_value)
  # convert to number vector
  mapped_x = unlist(mapped_x)
  
  return(mapped_x)
}

###

