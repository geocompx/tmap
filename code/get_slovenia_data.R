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
                             nuts_level = "3")
plot(slo_regions)

# Get population density
slo_popdens = get_eurostat("demo_r_d3dens", time_format = "num",
                           filters = list(geo = slo_regions$NUTS_ID)) |>
  filter(time >= 2003, time <= 2022)

# Get total population numbers
slo_population = get_eurostat("demo_r_pjanaggr3", time_format = "num",
                              filters = list(geo = slo_regions$NUTS_ID, age = "TOTAL", sex = "T")) |>
  filter(time >= 2003, time <= 2022)

# Merge all datasets
slo_regions2 = slo_regions |>
  left_join(slo_popdens, by = c("NUTS_ID" = "geo")) |>
  left_join(slo_population, by = c("NUTS_ID" = "geo", "time" = "time"))

# 3. Slovenia cities ----------------------------------------------------------
slo_cities0 = opq(st_bbox(slo) |> st_transform("EPSG:4326")) |>
  add_osm_feature(key = "place", value = c("city", "town")) |>
  osmdata_sf()

slo_cities0$osm_points

slo_cities = slo_cities0$osm_points |> 
  st_transform(crs(slo)) |>
  st_intersection(slo) |>
  mutate(population = as.numeric(population)) |>
  filter(population > 10000) |>
  select(name, population, place)

write_sf(slo_cities, "data/slovenia/slo_cities.gpkg")

# 4. Slovenia railroads -----------------------------------------------------------
slo_roads0 = opq(bbox = st_bbox(slo) |> st_transform("EPSG:4326")) |>
  add_osm_feature(key = "highway", value = c("motorway", "primary", "secondary")) |>
  osmdata_sf()

# plot(slo_roads0$osm_lines)

slo_roads2 = slo_roads0$osm_lines |> 
  st_transform(crs(slo)) |> 
  filter(highway %in% c("motorway", "primary", "secondary")) |> 
  select(name, highway, maxspeed) |> 
  mutate(strokelwd = recode(highway,
                            motorway = 10,
                            primary = 7,
                            secondary = 5
  )) |> 
  mutate(maxspeed = as.numeric(maxspeed)) |>
  group_by(highway, strokelwd) |>
  st_cast("LINESTRING")

slo_roads = slo_roads0$osm_lines |> 
  st_transform(crs(slo)) |> 
  filter(highway %in% c("motorway", "primary", "secondary")) |> 
  select(name, highway, maxspeed) |> 
  mutate(strokelwd = recode(highway,
                            motorway = 10,
                            primary = 7,
                            secondary = 5
  )) |> 
  mutate(maxspeed = as.numeric(maxspeed)) |>
  group_by(name, highway, strokelwd) |> 
  summarise() |> 
  st_collection_extract("LINESTRING") |> 
  mutate(name = ifelse(nchar(name) > 20, NA, name)) |> 
  rename(type = highway) |>
  st_intersection(slo)

plot(slo_roads)

slo_roads = slo_roads |>
  st_collection_extract("LINESTRING") |>
  mutate(length = as.numeric(st_length(geometry))) |>
  filter(length > 4000)

plot(slo_roads)

library(rnaturalearth)
slovenia_roads = ne_download(scale = 10, category = "cultural", type = "roads", returnclass = "sf") |>
  st_transform(crs(slo)) |>
  st_intersection(slo) |>
  select(type, length_km, labelrank, min_zoom, min_label)

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
  elevation = slo_elev#,
  # search = 10,
  # skip = 0,
  # flat = 2,
  # `-m` = 0,
  # `-e` = 1,
  # GRASS_REGION_CELLSIZE_PARAMETER = 25
)

slo_gm = qgis_as_terra(qgis_res$forms)
plot(slo_gm)
names(slo_gm) = "geomorphons"
writeRaster(slo_gm, "data/slovenia/slo_gm.tif")

# # 7. Slovenia satellite imagery ------------------------------------------------
# library(rsi)
# slo_sen2 = rsi::get_sentinel2_imagery(
#   aoi = slo,
#   start_date = "2021-01-01",
#   end_date = "2021-12-31",
#   pixel_x_size = 500,
#   pixel_y_size = 500,
#   cloud_cover = 10,
#   output_filename = "data/slovenia/slo_sen2.tif"
# )

# 7. Slovenia temperature ------------------------------------------------------
library(geodata)
slo_tavg0 = geodata::worldclim_country("Slovenia", var = "tavg", path = tempdir())
slo_tavg0 = project(slo_tavg0, crs(slo), res = 500)
slo_tavg = crop(slo_tavg0, slo, mask = TRUE)
plot(slo_tavg)
writeRaster(slo_tavg, "data/slovenia/slo_tavg.tif")

# 8. Triglav -------------------------------------------------------------------
triglav_park = opq("Slovenia") |> 
  add_osm_feature(key = "boundary", value = "national_park") |> 
  osmdata_sf()

triglav_borders = triglav_park$osm_multipolygons |>
  filter(name == "Triglavski narodni park") |>
  select(name = `name:en`) |>
  st_transform(crs(slo))
plot(triglav_borders)

write_sf(triglav_borders, "data/slovenia/triglav.gpkg")

# 9. Triglav sentinel-2 --------------------------------------------------------
triglav_sat = rsi::get_landsat_imagery(
  aoi = triglav_borders,
  start_date = "2020-01-01",
  end_date = "2024-12-31",
  pixel_x_size = 50,
  pixel_y_size = 50,
  # cloud_cover = 10,
  rescale_bands = TRUE,
  output_filename = "data/slovenia/triglav_sat2.tif"
)
ts = rast(triglav_sat)
plot(crop(ts, triglav_borders, mask = TRUE))
