# defaults to a positive-positive correlation, switch using rev=TRUE
quantile_membership <- function(x, quantiles=seq(0.1,0.9,0.1),
                                targets="default", out_range="default"){
  # check for 1 more target values than quantile cutoffs
  if(any(targets!="default")){ if((length(targets)-length(quantiles))!=1){print("ERROR: QUANTILE VARIABLE LENGTHS DON'T MATCH")}}
  
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
  l_value = l_value + (out_range[1] - min(l_value)) # shift left or right
  
  return(l_value)
}



test_array = rnorm(100, 50, 15)
# a = 15
# b = 85
a = quantile(test_array, 0.05)
b = quantile(test_array, 0.95)
# a = "min"
# b = "max"
r=T
test_out = linear_membership(test_array, upper_clamp = b, lower_clamp = a, rev=r, zero_offset = 0)

test_plot = ggplot() +
  theme_bw() +
  geom_point(aes(x=test_array, y=test_out)) +
  scale_y_continuous(limits = c(0,1))


