library(tidyverse)
library(amadeus)
library(terra)
library(sf)

gm_vars <- c("tmmn", "tmmx", "sph", "rmin","rmax")
yrs <- c(1995,2025)

zcta_file <- file.path("tl_2025_us_zcta520", "tl_2025_us_zcta520.shp")

# -----------------------------load gridMET data------------------------------ #
res <- download_data(dataset_name = "gridmet",
                     variables = gm_vars,
                     year = yrs,  
                     acknowledgement = TRUE,
                     directory_to_save = ".",
                     show_progress = TRUE)

# ----------------------------map lat/lon to ZIP5----------------------------- #
# read one gridMET file for grid layout 
r <- rast(file.path(gm_vars[1], paste0(gm_vars[1], "_", yrs[1], ".nc"))) 
r1 <- r[[1]] # use the first layer only; the grid is the same for every day/year 
cells <- 1:ncell(r1)
xy <- xyFromCell(r1, cells)
grid_points <- data.frame(
  cell = cells,
  longitude = xy[,1],
  latitude = xy[,2]
)

write_csv(grid_points, "gridmet_cell_latlon.csv")

zip_shp <- st_read(zcta_file)

# convert out Lat/Long to format needed for the sf package
points_sf <- st_as_sf(grid_points, 
                      coords = c("longitude", "latitude"), 
                      crs = 4326) # gridMET uses WGS 84 geographic coordinate reference system (EPSG 4326)
points_sf <- st_transform(points_sf, st_crs(zip_shp)) # convert to ref. system used by ZCTA file 

# perform a spatial join- looks up our coordinates in the ZIP code shapefile from us census beureau
joined <- st_join(points_sf, zip_shp["ZCTA5CE20"], left = TRUE)

# write results to a table
lookup <- as_tibble(st_drop_geometry(joined)) %>%
  rename("ZIP5" = "ZCTA5CE20") %>%
  mutate(ZIP3 = substr(ZIP5, 1, 3))

write_csv(lookup, file = "gridmet_zip3.csv")


