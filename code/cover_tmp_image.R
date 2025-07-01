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
    col.free = TRUE,
    col_alpha = 0.5) +
  tm_facets(ncol = 12) +
  tm_layout(panel.show = FALSE,
            frame = FALSE,
            bg.color = "#1c0e22ff",
            outer.bg.color = "#1c0e22ff")

# tm_shape(slo_tavg) +
#   tm_raster(
#     col.scale = tm_scale_continuous(values = "viridis"),
#     col.legend = tm_legend(show = FALSE),
#     col.free = TRUE,
#     col_alpha = 0.5) +
#   tm_facets(ncol = 12) +
#   tm_layout(panel.show = FALSE,
#             frame = FALSE,
#             bg.color = "#1c0e22ff",
#             outer.bg.color = "#1c0e22ff")


png("images/cover_tmp_image.png", width = 15.6, height = 23.4, 
    unit = "cm", res = 600, bg = "#1c0e22ff")  # Set background color
tm
dev.off()

# tmap_save(tm, "images/cover_tmp_image.png", width = 15.6, height = 23.4, 
          # unit = "cm", dpi = 600, device = png2)
browseURL("images/cover_tmp_image.png")

library(magick)
library(rsvg)

png_img = image_read("images/cover_tmp_image.png")  
svg_img = image_read_svg("images/cover_tmp.svg")  

svg_img = image_resize(svg_img, 
                       geometry_size_pixels(width = 15.6 * 600/2.54, height = 23.4 * 600/2.54))

composite_img = image_composite(png_img, svg_img, operator = "over")
print(composite_img)
magick::image_write(composite_img, "images/cover_tmp_all.png", format = "png")

