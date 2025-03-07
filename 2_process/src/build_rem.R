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
  n_row <- nrow(df)
  idx <- floor(seq(from = 1, to = n_row, length.out = n))
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
