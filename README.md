# ZIP3-level climate data 

This repo provides ZIP3-level daily averages for temperature and humidity from gridMET in `daily_means/` along with code to reproduce. 

Steps to reproduce: 
1. Download ZIP code shape files from [census.gov](https://www2.census.gov/geo/tiger/TIGER2025/ZCTA520/)
2. Run `loadGridMET_mapToZIP3.R`, modifying `gm_vars` to change variables (default: tmmn, tmmx, sph, rmin, rmax) and `yrs` to change years (default: 1995-2025). This script downloads gridMET data via amadeus and maps gridMET latitudes/longitudes to ZIP5 and ZIP3. 
3. Run `calc_over_ZIP3.R`, modifying `gm_vars` and `yrs` accordingly. For each year, generates a file of average daily values per ZIP3. By default, runs in parallel over `detectCores()-6`. 
