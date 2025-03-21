#' Create a polygon that bounds lat/long points
#'
#' @param pts_df data frame with "lat" and :ong" columns containing at least two
#'   rows.
#' @param out_crs crs of output polygon
#' @param in_crs crs of input polygon. Defaults to lat long: "EPSG: 4326".
#'
#' @returns SpatVector polygon
#'
envelop <- function(pts_df, out_crs, in_crs = "EPSG: 4326") {
  # Check assertions
  pts_df |>
    assertr::verify(assertr::has_only_names(c("lat", "lon"))) |>
    assertr::verify(assertr::has_class("lat", "lon", class = "numeric")) |>
    assertr::verify(length(lat) > 1)

  pts_df |>
    terra::vect(geom = c("lon", "lat"), crs = in_crs) |>
    terra::project(out_crs) |>
    terra::ext() |>
    terra::vect(crs = out_crs)
}

#' Crop a DEM (single or multiple files)
#'
#' @param dem_tif chr; path to a digital elevation model(s) in a format that can
#'   be read with `terra::rast()`. Can also handle multiple files with adjecent
#'   (or slightly overlapping) extents.
#' @param ext a terra SpatExtent object (created with `terra::ext()`) or some
#'   object that has an extent that can be derived using `terra::ext()`
#'
#' @return a wrapped terra SpatRaster; to use, this object must be unwrapped
#'   first using `terra::unwrap()`
#'
crop_tif <- function(dem_tif, lat_lon_df, scale = NULL, offset_frac = 0) {
  # Mosaic rasters if multiple files; otherwise, read in single raster
  if (length(dem_tif) > 1) {
    dem_rast <- terra::sprc(dem_tif) |>
      terra::mosaic()
  } else {
    dem_rast <- terra::rast(dem_tif)
  }

  ext_poly <- envelop(pts_df = lat_lon_df, out_crs = terra::crs(dem_rast))

  if (!is.null(scale)) {
    bbox <- terra::ext(ext_poly)
    old_width <- unname(bbox$xmax - bbox$xmin)
    old_height <- unname(bbox$ymax - bbox$ymin)
    in_scale <- old_width / old_height

    new_height <- old_width / scale
    height_diff <- (new_height - old_height) / 2

    offset_y <- offset_frac * new_height

    ext_poly <- envelop(
      pts_df = data.frame(
        lon = c(bbox$xmin, bbox$xmax),
        lat = c(bbox$ymin - height_diff, bbox$ymax + height_diff) + offset_y
      ),
      out_crs = terra::crs(dem_rast),
      in_crs = terra::crs(ext_poly)
    )
  }

  # Crop and set name
  dem_rast <- terra::crop(dem_rast, ext_poly) |>
    setNames("dem")

  return(dem_rast)
}

crop_flowlines <- function(
  flowline_path,
  layer,
  line_crs,
  lat_lon_df,
  out_crs,
  ReachCode_filter = NULL
) {
  ext_poly <- envelop(lat_lon_df, line_crs)

  out <- terra::vect(
    flowline_path,
    layer = layer,
    filter = ext_poly
  ) |>
    terra::intersect(ext_poly) |>
    terra::project(out_crs)

  if (!is.null(ReachCode_filter)) {
    out <- terra::subset(out, out$ReachCode %in% ReachCode_filter)
  }
  return(out)
}

resample_by_factor <- function(dem_rast, resample_factor = 2) {
  template_rast <- rast(
    #nrow = terra::nrow(dem_rast) * 2,
    #ncol = terra::ncol(dem_rast) * 2,
    crs = terra::crs(dem_rast),
    extent = terra::ext(dem_rast),
    resolution = terra::res(dem_rast) / resample_factor,
    vals = NA
  )
  terra::resample(dem_rast, template_rast) |>
    setNames("dem")
}
