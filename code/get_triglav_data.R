# devtools::install_github("e-sensing/sits@dev")
library(sits)
library(osmdata)
library(dplyr)
library(sf)
library(terra)
library(elevatr)

# trignav park borders
triglav_park = opq("Slovenia") |> 
        add_osm_feature(key = "boundary", value = "national_park") |> 
        osmdata_sf()

triglav_borders = triglav_park$osm_multipolygons |>
        dplyr::filter(name == "Triglavski narodni park") |>
        select(name = `name:en`)
plot(triglav_borders)

triglav_borders2 = st_transform(triglav_borders, "EPSG:3035")
write_sf(triglav_borders2, "data/slovenia/triglav_np.gpkg")

# sentinel 2 data
s2 = sits_cube(
        source = "MPC",
        collection = "SENTINEL-2-L2A",
        roi = triglav_borders,
        # bands = c("COASTAL-AEROSOL", "BLUE", "GREEN", "RED", "RED-EDGE-1", "RED-EDGE-2", "RED-EDGE-3", "NIR-1", "NIR-2", "SWIR-2", "SWIR-3", "CLOUD"),
        start_date = "2024-06-01",
        end_date = "2024-09-30"
)

s2_local = sits_cube_copy(
        cube = s2,
        output_dir = tempdir(),
        roi = triglav_borders,
        multicores = 6L,
        res = 50,
)

s2_reg = sits_regularize(s2_local, 
                          period = "P1Y",
                          res = 50,
                          multicores = 6L,
                          output_dir = tempdir())

r1 = rast(s2_reg$file_info[[1]]$path)
r2 = rast(s2_reg$file_info[[2]]$path)

r = mosaic(r1, r2)
r

rp = project(r, crs(triglav_borders2), res = 50)

# https://forum.sentinel-hub.com/t/l2a-images-to-range-0-to-1/2505
# https://www.cesbio.cnrs.fr/multitemp/16885-2/
rp = rp/10000 # to reflectance
rp = ifel(rp>1, 1, rp) # clip to 1

triglav_s2 = crop(rp, triglav_borders2, mask = TRUE)
writeRaster(triglav_s2, "data/slovenia/triglav_s2.tif")

# elevation
triglav_elev = rast(get_elev_raster(triglav_borders2, z = 11, clip = "bbox"))
triglav_elev = resample(triglav_elev, triglav_s2)
triglav_elev = crop(triglav_elev, triglav_borders2, mask = TRUE)
names(triglav_elev) = "elevation"
plot(triglav_elev)
writeRaster(triglav_elev, "data/slovenia/triglav_elev.tif")

