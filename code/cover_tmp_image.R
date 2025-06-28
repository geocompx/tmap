library(tmap)
library(terra)
slo_tavg = rast("data/slovenia/slo_tavg.tif")
n = 24
slo_tavg2 = rep(slo_tavg, n)
names(slo_tavg2) = paste0("tavg_", seq_len(nlyr(slo_tavg2)))

tm = tm_shape(slo_tavg2) +
  tm_raster(
    col.scale = tm_scale_continuous(values = "viridis"),
    col.legend = tm_legend(show = FALSE),
    col.free = TRUE) +
  tm_facets(ncol = 12) +
  tm_layout(panel.show = FALSE,
            frame = FALSE)

tmap_save(tm, "images/cover_tmp_image.png", width = 15.6, height = 23.4, 
          unit = "cm", dpi = 600)
browseURL("images/cover_tmp_image.png")
