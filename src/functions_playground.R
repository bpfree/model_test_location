
# returns a vector Z-membership of rescaled values from a vector input of number values
z_mem_function <- function(x, upper_clamp = "max", lower_clamp = "min",
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


# returns a vector s-membership of rescaled values from a vector input of number values
s_mem_function <- function(x, upper_clamp = "max", lower_clamp = "min",
                           zero_offset=(1/1000), out_range="default"){
  # get the lower clamp value from the input either taking the max or setting the value
  lower_clamp = ifelse(lower_clamp=="min", min(x, na.rm=TRUE), lower_clamp)
  # set the min and max values needed for the reduction equation.
  #Max gets the zero offset so that values don't equal 0.
  z_min = (lower_clamp - (lower_clamp*zero_offset))
  z_max = ifelse(upper_clamp=="max", max(x, na.rm=TRUE), upper_clamp)
  # clamp values below lower bound to the lower limit
  x = ifelse(x < lower_clamp, lower_clamp, x) 
  
  # calculate s-scores (more desired values get score of 1 while less desired will decrease till ~0)
  z_value <- ifelse(x>=z_max, 1, # if value is greater than or equal to max, score as 1
                    # if value is larger than minimum but lower than mid-value, calculate based on reduction equation.
                     # Values below min are already clamped.
                    ifelse(x<((z_min + z_max)/2), 2*(((x-z_min) / (z_max-z_min))**2),
                           # if value is larger than mid-value, calculate based on equation. 
                           ifelse(x>=((z_min + z_max)/2) & x<z_max, (1 - 2*((x-z_max) / (z_max-z_min))**2), NA) ) )
  
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


test_array = seq(100)
# a = 15
# b = 85
a = quantile(test_array, 0.1)
b = quantile(test_array, 0.9)
# a = "min"
# b = "max"
test_out = z_mem_function(test_array, upper_clamp = b, lower_clamp = a)

test_plot = ggplot() +
  theme_bw() +
  geom_point(aes(x=test_array, y=test_out)) +
  scale_y_continuous(limits = c(0,1))


