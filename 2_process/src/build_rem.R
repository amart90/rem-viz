build_rem <- function(
  dem,
  flowlines,
  n_stream_pts,
  refine_line,
  refine_params = list(buffer = 10, stream_quantile = 0.95)
) {
  stopifnot("dem" %in% names(dem))

  if (refine_line) {
    stopifnot(c("buffer", "stream_quantile") %in% names(refine_params))

    flowline_buff <- terra::buffer(flowlines, refine_params$buffer)
    dem$accum <- dem$dem |>
      # Remove depressions (by breaching)
      flowdem::breach() |>
      # Remove depressions (by filling)
      flowdem::fill(epsilon = TRUE) |>
      # Determine flow direction
      flowdem::dirs() |>
      # Determine flow accumulation
      flowdem::accum()
    dem$accum_buff <- terra::mask(dem$accum, flowline_buff)

    # Identify stream from flow accumulation
    stream_quant_value <- quantile(
      terra::values(dem$accum_buff),
      refine_params$stream_quantile,
      na.rm = TRUE
    )
    dem$stream <- (dem$accum_buff > stream_quant_value) |>
      terra::classify(cbind(0, NA))
  } else {
    dem$stream <- rasterize(flowlines, dem)
  }

  stream_pts <- terra::as.points(dem$stream) |>
    sample_regular(n_stream_pts) |>
    terra::extract(dem$dem, y = _, bind = T)

  dem$idw <- terra::interpIDW(
    #24s
    dem$dem,
    stream_pts,
    maxPoints = n_stream_pts,
    field = "dem",
    radius = max_dist_from_edge(stream_pts, dem$dem)
  )
  dem$rem <- dem$dem - dem$idw

  return(dem)
}

#' Take a regular sample of rows from a data frame-like object
#'
#' @param df a data frame-like object
#' @param n int, number of rows to sample
#'
#' @return an object, the same class as df with `n`, evenly spaced rows
#'
sample_regular <- function(df, n) {
  if (nrow(df) >= n) {
    return(df)
  }
  idx <- floor(seq(from = 1, to = nrow(df), length.out = n))
  df[idx, ]
}

#' The maximum distance from a point to the edge of a raster
#'
#' @param pts SpatVector with points geometry
#' @param r SpatRaster with a single layer
#'
#' @return num; the maximum distance (in crs units) from a point to the edge
#'
max_dist_from_edge <- function(pts, r) {
  # Convert points to raster
  terra::rasterize(pts, r) |>
    # Create raster where each cell in distance to nearest point
    terra::distance() |>
    # Return maximum distance from a point
    terra::global("max") |>
    # Coerce from data frame to numeric
    as.numeric() |>
    # Round up
    ceiling()
}

#' Build relative elevation model
#'
#' @param dem_tif chr; path to dem
#' @param aoi_ext named num vector; must have neames: xmin, xmax, ymin, ymax
#'   with coresponding lat/long coordinates
#' @param flowlines_gpkg chr; path to flowlines geopackage
#' @param n_stream_pts num(1); maximum number of points from flowlines to sample
#'
#' @returns a spatraster
#'
build_rem_3dhp <- function(
  dem_tif,
  aoi_ext,
  flowlines_gpkg,
  n_stream_pts = 800,
  max_points = 800,
  out_filename = NULL,
  flowline_gnisid = NULL,
  flowline_id3dhp = NULL,
  query_text = NULL
) {
  # Build extent polygon from c(xmin, ymax, ...)
  if (length(dem_tif) > 1) {
    dem <- terra::sprc(dem_tif) |>
      terra::merge()
  } else {
    dem <- terra::rast(dem_tif)
  }

  if (is.null(aoi_ext)) {
    aoi_vect <- terra::ext(dem) |>
      terra::as.polygons(crs = terra::crs(dem))
  } else {
    # Double check x/y min/max are in the right order
    aoi_ext_ <- aoi_ext
    aoi_ext_[["xmin"]] = min(aoi_ext[c("xmin", "xmax")])
    aoi_ext_[["xmax"]] = max(aoi_ext[c("xmin", "xmax")])
    aoi_ext_[["ymin"]] = min(aoi_ext[c("ymin", "ymax")])
    aoi_ext_[["ymax"]] = max(aoi_ext[c("ymin", "ymax")])

    aoi_sf <- sf::st_bbox(aoi_ext_) |>
      sf::st_as_sfc() |>
      sf::`st_crs<-`("EPSG:4326")

    aoi_vect <- aoi_sf |>
      sf::st_transform(terra::crs(dem)) |>
      terra::vect()
  }

  dem_aoi <- terra::crop(dem, aoi_vect) |>
    setNames("dem")

  query <- "SELECT * FROM flowlines WHERE"
  if (!is.null(query_text)) {
    query <- paste(query, query_text)
  } else if (!is.null(flowline_gnisid) & !is.null(flowline_id3dhp)) {
    query <- paste(
      query,
      sprintf("gnisid IN (%s)", flowline_gnisid),
      "OR",
      sprintf("id3dhp IN (%s)", flowline_id3dhp)
    )
  } else if (!is.null(flowline_gnisid)) {
    query <- paste(query, sprintf("gnisid IN (%s)", flowline_gnisid))
  } else if (!is.null(flowline_id3dhp)) {
    query <- paste(query, sprintf("id3dhp IN (%s)", flowline_id3dhp))
  } else {
    query <- paste(query, "onsurface = 1")
  }

  flowlines_vect <- terra::vect(
    flowlines_gpkg,
    layer = "flowlines",
    query = query,
    filter = aoi_vect
  )

  dem_aoi$stream <- terra::rasterize(flowlines_vect, dem_aoi)

  stream_pts <- terra::as.points(dem_aoi$stream)
  rlang::inform(sprintf("nrow(stream_pts) = %s", nrow(stream_pts)))

  stream_pts <- stream_pts |>
    sample_regular(n_stream_pts) |>
    terra::extract(dem_aoi$dem, y = _, bind = T)

  dem_aoi$idw <- terra::interpIDW(
    dem_aoi$dem,
    stream_pts,
    maxPoints = max_points,
    field = "dem",
    radius = max_dist_from_edge(stream_pts, dem_aoi$dem)
  )
  dem_aoi$rem <- dem_aoi$dem - dem_aoi$idw

  if (is.null(out_filename)) {
    return(dem_aoi)
  } else {
    terra::writeRaster(dem_aoi$rem, out_filename, overwrite = TRUE)
    return(out_filename)
  }
}
