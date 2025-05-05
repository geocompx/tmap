# NOT USED ANYMORE (2025-05-05)
# # devtools::install_github("e-sensing/sits@dev")
# library(sits)
# library(osmdata)
# library(dplyr)
# library(sf)
# library(terra)
# library(elevatr)
# 
# # protected_area
# protected_area = opq("Slovenia") |> 
#         add_osm_feature(key = "boundary", value = "protected_area") |> 
#         osmdata_sf()
# 
# # triglav_borders = triglav_park$osm_multipolygons |>
# #         dplyr::filter(name == "Triglavski narodni park") |>
# #         select(name = `name:en`)
# # plot(triglav_borders)
# # 
# # triglav_borders2 = st_transform(triglav_borders, "EPSG:3035")
# # write_sf(triglav_borders2, "data/slovenia/triglav_np.gpkg")
# 
# park_borders = protected_area$osm_multipolygons |>
#   dplyr::filter(name == "Krajinski park Radensko polje") |>
#   select(name = `name:en`)
# plot(park_borders)
#   
# park_borders2 = st_transform(park_borders, "EPSG:3035")
# 
# # sentinel 2 data
# s2 = sits_cube(
#         source = "MPC",
#         collection = "SENTINEL-2-L2A",
#         roi = park_borders,
#         # bands = c("COASTAL-AEROSOL", "BLUE", "GREEN", "RED", "RED-EDGE-1", "RED-EDGE-2", "RED-EDGE-3", "NIR-1", "NIR-2", "SWIR-2", "SWIR-3", "CLOUD"),
#         start_date = "2023-08-12",
#         end_date = "2023-08-14"
# )
# s2_local = sits_cube_copy(
#         cube = s2,
#         output_dir = tempdir(),
#         roi = park_borders,
#         multicores = 6L,
#         res = 10,
# )
# 
# s2_reg = sits_regularize(s2_local, 
#                           period = "P1Y",
#                           res = 10,
#                           multicores = 6L,
#                           output_dir = tempdir())
# 
# r = rast(s2_reg$file_info[[1]]$path)
# 
# rp = project(r, crs(park_borders2), res = 10)
# 
# # https://forum.sentinel-hub.com/t/l2a-images-to-range-0-to-1/2505
# # https://www.cesbio.cnrs.fr/multitemp/16885-2/
# rp = rp/10000 # to reflectance
# rp = ifel(rp>1, 1, rp) # clip to 1
# 
# plotRGB(rp[[2:4]], stretch = "hist", r = 3, g = 2, b = 1)
# 
# park_s2 = crop(rp, park_borders2, mask = TRUE)
# writeRaster(park_s2, "data/slovenia/park_sat2.tif", overwrite = TRUE)
# 
# # elevation
# park_elev = rast(get_elev_raster(park_borders2, z = 11, clip = "bbox"))
# park_elev = resample(park_elev, park_s2)
# park_elev = crop(park_elev, park_borders2, mask = TRUE)
# names(park_elev) = "elevation"
# plot(park_elev)
# writeRaster(park_elev, "data/slovenia/park_elev.tif")
# 
# park_sat = rsi::get_sentinel2_imagery(
#   aoi = park_borders2,
#   start_date = "2023-08-13",
#   end_date = "2023-08-13",
#   pixel_x_size = 10,
#   pixel_y_size = 10,
#   # cloud_cover = 10,
#   rescale_bands = TRUE,
#   output_filename = "data/slovenia/park_sat2b.tif"
# )
# ps = rast(park_sat)
# ps = ps/10000 # to reflectance
# ps = ifel(ps>1, 1, ps) # clip to 1
# writeRaster(ps, "data/slovenia/park_sat2c.tif")
# 
# plotRGB(ps, stretch = "lin", r = 3, g = 2, b = 1)
# 
# ps2 = stretch(ps, minq = 0.1, maxq = 0.94)
# plotRGB(ps2, r = 3, g = 2, b = 1)
