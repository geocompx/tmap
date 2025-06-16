# remotes::install_github("rOpenGov/giscoR")
library(giscoR)
library(eurostat)
library(dplyr)
library(elevatr)
library(terra)
library(sf)
library(osmdata)

# 1. Slovenia borders ----------------------------------------------------------
slo = gisco_get_countries(year = "2024", epsg = "3035", resolution = "01",
                          spatialtype = "RG", country = "Slovenia") |>
      select(Name = NAME_ENGL)
plot(slo)

write_sf(slo, "data/slovenia/slo_border.gpkg")

eur = gisco_get_countries(year = "2024", epsg = "3035", resolution = "01",
                          spatialtype = "RG", region = "Europe") |>
      select(Name = NAME_ENGL)

slo_buf = st_buffer(slo, 50000)
slo_neigh = st_filter(eur, slo_buf)

# 2. Slovenia regions ----------------------------------------------------------
slo_regions = gisco_get_nuts(year = "2024", epsg = "3035", resolution = "01",
                             spatialtype = "RG", country = "Slovenia",
                             nuts_level = "3") |>
  select(NUTS_ID, NUTS_NAME, URBN_TYPE) |>
  st_collection_extract("POLYGON")
plot(slo_regions)

# Get population density
slo_popdens = get_eurostat("demo_r_d3dens", time_format = "num",
                           filters = list(geo = slo_regions$NUTS_ID)) |>
  filter(time >= 2003, time <= 2022) |>
  select(geo, time, pop_dens = values)

# Get total population numbers
slo_population = get_eurostat("demo_r_pjanaggr3", time_format = "num",
                              filters = list(geo = slo_regions$NUTS_ID, age = "TOTAL", sex = "T")) |>
  filter(time >= 2003, time <= 2022) |>
  select(geo, time, population = values)

# population aged 65+
slo_pop65 = get_eurostat("demo_r_pjangrp3", time_format = "num",
                            filters = list(geo = slo_regions$NUTS_ID, 
                                           age = c("Y65-69", "Y70-74", "Y75-79",
                                           "Y80-84", "Y_GE85", "Y_GE90"),
                                           sex = "T")) |>
  filter(time >= 2003, time <= 2022) |>
  group_by(geo, time) |>
  summarise(values = sum(values)) |>
  select(geo, time, pop65 = values)

# gdppercap
slo_gdppercap = get_eurostat("nama_10r_3gdp", time_format = "num",
                              filters = list(geo = slo_regions$NUTS_ID,
                                             unit = "EUR_HAB")) |>
  filter(time >= 2003, time <= 2022) |>
  select(geo, time, gdppercap = values)

# turism (total turist per km2 in various types of accommodation)
slo_tourism = get_eurostat("tour_occ_nin3", time_format = "num",
                         filters = list(geo = slo_regions$NUTS_ID,
                                        c_resid = "TOTAL",
                                        unit = "P_KM2",
                                        nace_r2 = "I551-I553")) |>
  filter(time >= 2003, time <= 2022) |>
  select(geo, time, tourism = values)

slovenia_regions = tibble::tibble(
  region_name = c("Pomurska", "Podravska", "Koroška", "Savinjska", "Zasavska", 
                  "Posavska", "Jugovzhodna Slovenija", "Primorsko-notranjska", 
                  "Osrednjeslovenska", "Gorenjska", "Goriška", "Obalno-kraška"),
  region_group = c("East", "East", "North", "Central", "Central", 
                   "South", "South", "West", 
                   "Central", "North", "West", "West")
)

# Merge all datasets
slo_regions2 = slo_regions |>
  mutate(URBN_TYPE = as.numeric(slo_regions$URBN_TYPE)) |>
  rename(urbn_type = URBN_TYPE) |>
  mutate(urbn_type_col = case_when(
    urbn_type == 2 ~ "#2CA02C",
    urbn_type == 3 ~ "#994F88",
  )) |>
  left_join(slo_popdens, by = c("NUTS_ID" = "geo")) |>
  left_join(slo_population, by = c("NUTS_ID" = "geo", "time" = "time")) |>
  left_join(slo_gdppercap, by = c("NUTS_ID" = "geo", "time" = "time")) |>
  left_join(slo_tourism, by = c("NUTS_ID" = "geo", "time" = "time")) |>
  left_join(slo_pop65, by = c("NUTS_ID" = "geo", "time" = "time")) |>
  mutate(pop65perc = pop65 / population * 100) |>
  left_join(slovenia_regions, by = c("NUTS_NAME" = "region_name")) |>
  rename(id = NUTS_ID, region_name = NUTS_NAME)

write_sf(slo_regions2, "data/slovenia/slo_regions_ts.gpkg")

slo_regions2022 = slo_regions2 |>
  filter(time == 2022)

write_sf(slo_regions2022, "data/slovenia/slo_regions.gpkg")

# 3. Slovenia cities ----------------------------------------------------------
slo_cities0 = opq(st_bbox(slo) |> st_transform("EPSG:4326")) |>
  add_osm_feature(key = "place", value = c("city", "town")) |>
  osmdata_sf()

# slo_cities0$osm_points

slo_cities = slo_cities0$osm_points |> 
  st_transform(crs(slo)) |>
  st_intersection(slo) |>
  mutate(population = as.numeric(population)) |>
  filter(population > 10000) |>
  select(name, population, place)

write_sf(slo_cities, "data/slovenia/slo_cities.gpkg")

# 4. Slovenia railroads -----------------------------------------------------------
# https://ipi.eprostor.gov.si/jgp/data
# slo_railroads = read_sf("data-raw/DTM_SLO_PROMETNA_OMREZJA_TN_ZELEZNICE_L_20250412/DTM_SLO_PROMETNA_OMREZJA_TN_ZELEZNICE_L_line.shp") |>
#   st_transform(crs(slo)) 
# 
# slo_railroads = slo_railroads[!st_is_empty(slo_railroads), ]
# slo_railroads = st_zm(slo_railroads)

slo_railroads = read_sf("/vsizip/vsicurl/https://geodata.ucdavis.edu/diva/rrd/SVN_rrd.zip")
slo_railroads = slo_railroads[, c(1, 3, 4)]
names(slo_railroads) = c("id", "rail_status", "track_type", "geometry")
slo_railroads$track_width = factor(slo_railroads$track_type, levels = c("Unknown", "Single", "Multiple"))
slo_railroads$track_width = as.numeric(slo_railroads$track_width)^2
write_sf(slo_railroads, "data/slovenia/slo_railroads.gpkg")

# 5. Slovenia elevation -------------------------------------------------------
slo_elev0 = rast(get_elev_raster(slo, z = 8, clip = "bbox")) 
plot(slo_elev0)

slo_raster_template = rast(slo)
res(slo_raster_template) = 200

slo_elev0 = resample(slo_elev0, slo_raster_template)
plot(slo_elev0)

crs(slo_elev0) = crs(slo)
names(slo_elev0) = "elevation"

slo_elev = crop(slo_elev0, slo, mask = TRUE)
plot(slo_elev)
dir.create("data/slovenia")
writeRaster(slo_elev, "data/slovenia/slo_elev.tif")

# 6. Slovenia geomorphons ------------------------------------------------------
library(qgisprocess)
# View(qgis_algorithms())
# qgis_show_help("grass7:r.geomorphon")

qgis_res = qgis_run_algorithm(
  "grass:r.geomorphon",
  elevation = slo_elev,
  search = 24,      # Larger window (50 cells) — looks at broader landscape features
  dist = 8,        # Distance to recognize patterns (larger = more generalized forms)
  flat = 4,         # Tolerate small slopes as "flat" (in degrees) — more forgiving
  `-e` = 1          # Extended form output (keeps classes meaningful)
)

slo_gm = qgis_as_terra(qgis_res$forms)
plot(slo_gm)
names(slo_gm) = "geomorphons"
writeRaster(slo_gm, "data/slovenia/slo_gm.tif", overwrite = TRUE)

# 7. Slovenia satellite imagery ------------------------------------------------
# see `get_slovenia_mosaic_code.R`

# 8. Slovenia temperature ------------------------------------------------------
library(geodata)
slo_tavg0 = geodata::worldclim_country("Slovenia", var = "tavg", path = tempdir())
slo_tavg0 = project(slo_tavg0, crs(slo), res = 500)
slo_tavg = crop(slo_tavg0, slo, mask = TRUE)
names(slo_tavg) = paste("tavg", 1:12, sep = "_")
plot(slo_tavg)

writeRaster(slo_tavg, "data/slovenia/slo_tavg.tif", overwrite = TRUE)
