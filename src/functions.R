
# returns a vector Z-membership of rescaled values from a vector input of number values
z_mem_function <- function(x, upper_clamp = "max", lower_clamp = "min"){
  
  z_max = ifelse(upper_clamp=="max", (max(x) + (max(x) / 1000)), (upper_clamp + upper_clamp / 1000))
  z_min = ifelse(lower_clamp=="min", min(x), lower_clamp)
  
  # calculate z-scores (more desired values get score of 1 while less desired will decrease till 0)
  z_value <- ifelse(x<=z_min, 1, # if value is equal to minimum, score as 1
                    # if value is larger than minimum but lower than mid-value, calculate based on reduction equation
                    ifelse(x>z_min & x<((z_min + z_max)/2), (1 - 2*((x-z_min) / (z_max-z_min))**2),
                           # if value is larger than mid-value but lower than maximum, calculate based on equation
                           ifelse(x>=((z_min + z_max)/2) & x<z_max, 2*(((x-z_max) / (z_max-z_min))**2),
                                  # if value is equal to maximum, score min - (min * 1 / 1000); otherwise give NA
                                  ifelse(x>=z_max, 0, NA))))
  return(z_value)
}

