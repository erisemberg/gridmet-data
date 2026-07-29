library(terra)
library(readr)
library(dplyr)
library(tidyr)
library(purrr)
library(foreach)
library(doParallel)

# average rmin, rmax, sph, tmmn, tmmx per day/ZIP3

save_dir <- "daily_means"
gm_vars <- c("tmmn", "tmmx", "sph", "rmin","rmax")
yrs <- 1995:2025

#n_cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK"))
n_cores <- parallel::detectCores() - 6
if (is.na(n_cores) ||n_cores < 1) n_cores <- 1

cl <- makeCluster(n_cores)
registerDoParallel(cl)

on.exit(stopCluster(cl), add = TRUE)
  
lookup_file <- "gridmet_zip3.csv"
lookup <- read_csv(lookup_file, show_col_types = FALSE)

# -------------------------get average heat/humidity-------------------------- #
# give each ZIP3 a numeric ID
zip3_map <- lookup %>%
  filter(!is.na(ZIP3)) %>%
  distinct(ZIP3) %>%
  arrange(ZIP3) %>%
  mutate(zip3_id = row_number())

lookup <- lookup %>%
  left_join(zip3_map, by = "ZIP3")

# use one gridMET file as the template for the grid 
template <- rast(file.path(gm_vars[1], paste0(gm_vars[1], "_", yrs[1], ".nc")))[[1]]

# create a raster of ZIP3 IDs on the same grid as gridMET
zip3_values <- rep(NA_integer_, ncell(template))
zip3_values[lookup$cell] <- lookup$zip3_id
zip3_r <- setValues(template, zip3_values)

# save to file so it can be loaded in parallel processes (bc passing Raster objects 
# into parallel workers is fragile?)
zip3_r_path <- file.path("zip3_r.tif")
writeRaster(zip3_r, zip3_r_path, overwrite = TRUE)

process_one_file <- function(file, varname, zip3_r_path, zip3_map) {
  r <- rast(file)
  dates <- as.Date(time(r))
  zip3_r <- rast(zip3_r_path) # load ZIP3 raster map from file 
  
  # average each day over ZIP3 zones
  z <- as.data.frame(zonal(r, zip3_r, fun = mean, na.rm = TRUE))
  names(z) <- c("zip3_id", as.character(seq_along(dates)))
  
  long <- z %>%
    pivot_longer(cols = -zip3_id, names_to = "day_index", values_to = paste0("mean_", varname)) %>%
    mutate(
      day_index = as.integer(day_index),
      date = dates[day_index]
    ) %>%
    select(zip3_id, date, !!paste0("mean_", varname)) %>%
    left_join(zip3_map, by = "zip3_id") %>%
    select(ZIP3, date, !!paste0("mean_", varname))
  
  # make sure every ZIP3/date combination exists, even if some are NA
  complete_grid <- expand_grid(
    ZIP3 = zip3_map$ZIP3, 
    date = dates
  ) %>%
    left_join(long, by = c("ZIP3", "date"))
  
  return(complete_grid)
}

process_one_year <- function(year, zip3_r_path, zip3_map, vars) {
  var_tables <- purrr::map(vars, function(v) {
    message(paste("Processing variable:", v))
    file <- file.path(v, paste0(v, "_", year, ".nc"))
    process_one_file(file, v, zip3_r_path, zip3_map)
  })
  
  # merge all variables into one table for the year
  out <- purrr::reduce(var_tables, full_join, by = c("ZIP3", "date"))
  return(out)
}

foreach(yr = yrs, .packages = c("terra", "dplyr", "tidyr", "purrr", "readr")) %dopar% {
  message("Processing year: ", yr)

  year_df <- process_one_year(yr, zip3_r_path, zip3_map, gm_vars)

  write.csv(
    year_df,
    file = file.path(save_dir, paste0("zip3_daily_means_", yr, ".csv")),
    row.names = FALSE
  )

  NULL
}


