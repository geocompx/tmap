library(dplyr)
library(sf)
library(terra)
library(giscoR)

# Load Slovenia country boundaries
slo = gisco_get_countries(year = "2024", epsg = "3035", resolution = "01",
                          spatialtype = "RG", country = "Slovenia") |>
  select(Name = NAME_ENGL)
plot(slo)

# https://documentation.dataspace.copernicus.eu/APIs/S3.html#accessing-eodata-via-aws-cli
# Define the STAC API endpoint
stac_url = "https://stac.dataspace.copernicus.eu/v1/"

# Specify the AWS credentials and endpoint
Sys.setenv(
  # AWS_ACCESS_KEY_ID = "", # to be filled in
  # AWS_SECRET_ACCESS_KEY = "", # to be filled in
  AWS_DEFAULT_REGION = "default",
  AWS_ENDPOINT_URL = "https://eodata.dataspace.copernicus.eu/",
  AWS_VIRTUAL_HOSTING = "FALSE"
)

# Connect to STAC API
stac_source = rstac::stac(stac_url)

# Check available collections
stac_source |>
  rstac::collections() |>
  rstac::get_request()

# Focus on the Sentinel-2 Global Mosaics collection
collection_id = "sentinel-2-global-mosaics"
# my_datetime = "2024-04-01/2024-06-30"

# Search for items in the collection
search_res = rstac::stac_search(
  q = stac_source,
  collections = collection_id,
  bbox = st_bbox(st_transform(slo, crs = st_crs(4326))),
  datetime = "2024-04-01T00:00:00Z/2024-06-30T23:59:59Z",
  limit = 999
) |>
  rstac::get_request()

# Getting urls of specific bands (assets)
get_asset = function(x, assets = c("B02", "B03", "B04", "B08")){
  x_assets = x$assets[assets]
  purrr::map_chr(x_assets, "href")
}

all_urls = purrr::map(search_res$features, get_asset) |> unlist()

# Check if aws cli is installed (otherwise install it)
system("aws --version")

# Download the data
get_s3 = function(url){
  output = paste0(basename(dirname(url)), "_", basename(url))
  command = paste0("aws s3 cp ", url, paste0(" data/mosaic/", output))
  system(command)
}
dir.create("data/mosaic/")
purrr::walk(all_urls[[1]], get_s3)

# Load the downloaded data and mosaic them
all_r = dir("data/mosaic/", full.names = TRUE)

# split into four lists of B02, B03, B04, B08 with file paths
all_r_b2 = mosaic(sprc(purrr::map(all_r[grepl("B02", all_r)], rast))) |> setNames("B02")
all_r_b3 = mosaic(sprc(purrr::map(all_r[grepl("B03", all_r)], rast))) |> setNames("B03")
all_r_b4 = mosaic(sprc(purrr::map(all_r[grepl("B04", all_r)], rast))) |> setNames("B04")
all_r_b8 = mosaic(sprc(purrr::map(all_r[grepl("B08", all_r)], rast))) |> setNames("B08")

# Combine the bands into a single SpatRaster
all_rr = c(all_r_b2, all_r_b3, all_r_b4, all_r_b8)
# plotRGB(all_rr, stretch = "hist", r = 3, g = 2, b = 1)

# Crop/mask the raster to Slovenia
slo32633 = st_transform(slo, crs = st_crs(all_rr))
all_rr_slo = crop(all_rr, slo32633, mask = TRUE)
# plotRGB(all_rr_slo, stretch = "lin", r = 3, g = 2, b = 1)
# plotRGB(all_rr_slo, stretch = "lin", r = 4, g = 3, b = 2)

# Convert to reflectance and clip to 0-1
all_rr_slor = all_rr_slo/10000 # to reflectance
all_rr_slor = ifel(all_rr_slor>1, 1, all_rr_slor) # clip to 1
all_rr_slor = ifel(all_rr_slor<0, 0, all_rr_slor) # clip to 0

# Aggregate and project to the lower (200m) resolution
all_rr_slo_simpl = aggregate(all_rr_slor, fact = 20, fun = mean)
all_rr_slo_simpl = project(all_rr_slo_simpl, crs(slo))
# plotRGB(all_rr_slo_simpl, stretch = "lin", r = 4, g = 3, b = 2)
# plotRGB(all_rr_slo_simpl, stretch = "lin", r = 3, g = 2, b = 1)

# Save the final raster
dir.create("data/slovenia")
writeRaster(all_rr_slo_simpl, "data/slovenia/slo_mosaic.tif", overwrite = TRUE)
