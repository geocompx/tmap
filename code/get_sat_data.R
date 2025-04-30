# devtools::install_github("e-sensing/sits@dev")
library(sits)
library(dplyr)
library(sf)
library(terra)
library(elevatr)
library(giscoR)

slo = gisco_get_countries(year = "2024", epsg = "3035", resolution = "01",
                          spatialtype = "RG", country = "Slovenia") |>
  select(Name = NAME_ENGL)
plot(slo)
  
# sentinel 2 data
s2 = sits_cube(
        source = "MPC",
        collection = "SENTINEL-2-L2A",
        roi = slo,
        # bands = c("COASTAL-AEROSOL", "BLUE", "GREEN", "RED", "RED-EDGE-1", "RED-EDGE-2", "RED-EDGE-3", "NIR-1", "NIR-2", "SWIR-2", "SWIR-3", "CLOUD"),
        start_date = "2025-03-18",
        end_date = "2025-03-21"
)
s2_local = sits_cube_copy(
        cube = s2,
        output_dir = tempdir(),
        roi = slo,
        multicores = 6L,
        res = 200,
)

s2_reg = sits_regularize(s2_local, 
                          period = "P1Y",
                          res = 200,
                          multicores = 6L,
                          output_dir = tempdir())

r = rast(s2_reg$file_info[[1]]$path)

rp = project(r, crs(slo), res = 200)

# https://forum.sentinel-hub.com/t/l2a-images-to-range-0-to-1/2505
# https://www.cesbio.cnrs.fr/multitemp/16885-2/
rp = rp/10000 # to reflectance
rp = ifel(rp>1, 1, rp) # clip to 1

plotRGB(rp[[2:4]], stretch = "hist", r = 3, g = 2, b = 1)

park_s2 = crop(rp, park_borders2, mask = TRUE)
writeRaster(park_s2, "data/slovenia/park_sat2.tif", overwrite = TRUE)

# elevation
triglav_elev = rast(get_elev_raster(triglav_borders2, z = 11, clip = "bbox"))
triglav_elev = resample(triglav_elev, triglav_s2)
triglav_elev = crop(triglav_elev, triglav_borders2, mask = TRUE)
names(triglav_elev) = "elevation"
plot(triglav_elev)
writeRaster(triglav_elev, "data/slovenia/triglav_elev.tif")

park_sat = rsi::get_sentinel2_imagery(
  aoi = slo,
  start_date = "2025-03-18",
  end_date = "2025-03-21",
  pixel_x_size = 200,
  pixel_y_size = 200,
  # cloud_cover = 10,
  rescale_bands = TRUE,
  output_filename = "data/slovenia/park_sat2d.tif"
)
ps = rast(park_sat)
ps = ps/10000 # to reflectance
ps = ifel(ps>1, 1, ps) # clip to 1
writeRaster(ps, "data/slovenia/park_sat2c.tif")

plotRGB(ps, stretch = "lin", r = 3, g = 2, b = 1)
plotRGB(ps, stretch = "lin", r = 3, g = 2, b = 1)

ps2 = stretch(ps, minq = 0.1, maxq = 0.95)
plotRGB(mask(ps2, slo), r = 3, g = 2, b = 1)

plotRGB(mask(ps2, slo), r = 4, g = 3, b = 2)
