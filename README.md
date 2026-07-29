# ZIP3-level climate data 

This repo provides ZIP3-level daily averages for temperature and humidity from gridMET in `daily_means/` along with code to reproduce. 

```
git clone https://github.com/erisemberg/gridmet-data.git
mkdir gridmet-data/unzipped
cp gridmet-data/daily_means/*.csv.gz gridmet-data/unzipped/
gunzip gridmet-data/unzipped/*.csv.gz
```

Example use case (calculating average temp/humidity for 90 days after drug start date), connecting to dataset in DuckDB to avoid loading into memory:

```
library(duckdb)
library(DBI) 

csv_dir <- file.path(dir_data, "gridmet-data", "unzipped")
files <- list.files(csv_dir,
                    pattern = "^zip3_daily_means_.*\\.csv$",
                    full.names = TRUE)
duckdb_read_csv(
  duck_con,
  name = "exposures",
  files = files,
  temporary = TRUE,
  header = TRUE,
  delim = ","
)

duckdb_register(duck_con, "dat", dat)

query <- "
  WITH exposures_parsed AS (
    SELECT
      ZIP3,
      CAST(date AS DATE) AS date,
      mean_tmmn, 
      mean_tmmx,
      mean_sph,
      mean_rmin,
      mean_rmax
    FROM exposures
  ),
  person_days AS (
    SELECT
      person_id,
      zip3_padded,
      drug_era_start_date + CAST(i AS INTEGER) AS date
    FROM dat
    CROSS JOIN range(0, 91) AS t(i)
  ),
  joined AS (
    SELECT
      pd.person_id,
      e.mean_tmmn,
      e.mean_tmmx,
      e.mean_sph,
      e.mean_rmin,
      e.mean_rmax
    FROM person_days pd
    LEFT JOIN exposures_parsed e
      ON CAST(pd.zip3_padded AS INTEGER) = e.ZIP3
     AND pd.date = e.date
  )
  SELECT
    person_id,
    AVG(mean_tmmn) AS avg_tmmn_91d,
    AVG(mean_tmmx) AS avg_tmmx_91d,
    AVG(mean_sph)  AS avg_sph_91d,
    AVG(mean_rmin) AS avg_rmin_91d,
    AVG(mean_rmax) AS avg_rmax_91d
  FROM joined
  GROUP BY person_id
"

exposure_91d <- dbGetQuery(duck_con, query)

dat <- dat %>%
  left_join(exposure_91d, by = "person_id")
```

Steps to reproduce: 
1. Download ZIP code shape files from [census.gov](https://www2.census.gov/geo/tiger/TIGER2025/ZCTA520/)
2. Run `loadGridMET_mapToZIP3.R`, modifying `gm_vars` to change variables (default: tmmn, tmmx, sph, rmin, rmax) and `yrs` to change years (default: 1995-2025). This script downloads gridMET data via `amadeus` and maps gridMET latitudes/longitudes to ZIP5 and ZIP3. 
3. Run `calc_over_ZIP3.R`, modifying `gm_vars` and `yrs` accordingly. For each year, generates a file of average daily values per ZIP3. By default, runs in parallel over `detectCores()-6`. 
