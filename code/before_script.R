library(methods)
library(webshot)
library(ragg)
set.seed(2020-05-06)
options(digits = 3)
tmap::tmap_options(scale = 0.8)

knitr::knit_hooks$set(
  crop = knitr::hook_pdfcrop,
  optipng = knitr::hook_optipng
)

knitr::opts_chunk$set(
  background = "#FCFCFC", # code chunk color in latex
  comment = "#>",
  collapse = TRUE,
  # cache = TRUE, #https://github.com/rstudio/bookdown/issues/15#issuecomment-591478143
  # fig.pos = "h", #"t"
  fig.path = "figures/",
  fig.align = "center",
  fig.retina = 2,
  # fig.height = 7,
  fig.width = 9,
  fig.asp = 0.618,  # 1 / phi
  fig.show = "hold",
  # dpi = 150,
  out.width = "100%", #70%
  # dev.args = list(png = list(type = "cairo-png")),
  dev = "ragg_png",
  optipng = "-o2 -quiet",
  widgetframe_widgets_dir = "widgets",
  screenshot.opt = list(delay = 0.3)
)

if(!knitr:::is_html_output()){
  options("width" = 56)
  knitr::opts_chunk$set(tidy.opts = list(width.cutoff = 56, indent = 2),
                        tidy = TRUE)
}

view_map = function(x, name){
  if (knitr::is_latex_output()){
    tf = tempfile(fileext = ".html")
    tmap::tmap_save(x, tf)
    webshot2::webshot(tf, file = paste0("widgets/", name, ".png"))
    knitr::include_graphics(paste0("widgets/", name, ".png"))
  } else {
    # widgetframe::frameWidget(tmap::tmap_leaflet(x))
    # tmap::tmap_leaflet(x)
    x
  }
}

# Sys.setenv(CHROMOTE_CHROME = "/usr/bin/vivaldi")
