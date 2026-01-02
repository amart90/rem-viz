# install.packages(c("terra","classInt","scales"))
library(terra)
library(classInt)
library(scales)

auto_rem_values <- function(
  rem, # SpatRaster
  method = "quantile_power",
  n_stops = 15, # number of color stops (>=3)
  upper_clamp_q = 0.90, # your usual upper clamp
  lower_clamp = NULL, # e.g., 0.01 to trim low outliers; NULL = min(v)
  transform = c("asinh", "log1p", "none"),
  power = 2.2, # >1 concentrates stops toward low end
  palette = NULL, # default constructed below
  cold_low_anchor = TRUE, # add subtle cool anchor at the low end
  seed = 42
) {
  stopifnot(inherits(rem, "SpatRaster"))
  method <- match.arg(method)
  transform <- match.arg(transform)
  set.seed(seed)

  v <- values(rem, mat = FALSE)
  v <- v[is.finite(v)]
  stopifnot("No finite values in REM." = length(v) > 0)

  lo <- if (is.null(lower_clamp)) {
    min(v, na.rm = TRUE)
  } else if (rlang::is_scalar_double(lower_clamp)) {
    lower_clamp
  } else if (is.function(lower_clamp)) {
    lower_clamp(v)
  } else {
    stop(
      "lower_clamp must be NULL, a number, or a function that returns a single number."
    )
  }

  if (!rlang::is_scalar_double(lo)) {
    stop("If lower_clamp is a function, it must return a single numeric")
  }

  hi <- as.numeric(quantile(v, upper_clamp_q, na.rm = TRUE))

  stopifnot(
    "Bad clamp limits; check quantiles." = all(
      is.finite(lo),
      is.finite(hi),
      lo < hi
    )
  )

  v_clip <- pmin(pmax(v, lo), hi)

  tf <- switch(
    transform,
    "none" = identity,
    "log1p" = \(x) ifelse(x - lo >= 0, log1p(x - lo), -log1p(lo - x)),
    "asinh" = \(x) asinh(x - lo)
  )

  itf <- switch(
    transform,
    "none" = identity,
    "log1p" = \(y) ifelse(y >= 0, lo + expm1(y), lo - expm1(-y)),
    "asinh" = \(y) lo + sinh(y)
  )

  vt <- tf(v_clip)

  # Stop positions in transformed domain
  if (method == "quantile_power") {
    p <- seq(0, 1, length.out = n_stops)
    pu <- p^power
    stt <- as.numeric(quantile(vt, probs = pu, na.rm = TRUE, names = FALSE))
    stt <- sort(unique(stt))
    # guarantee endpoints
    stt[1] <- min(vt, na.rm = TRUE)
    stt[length(stt)] <- max(vt, na.rm = TRUE)
  } else {
    stop("Unsupported method.")
  }

  # Map back to original space (for computing normalized positions)
  stops <- itf(stt)
  stops[1] <- lo
  stops[length(stops)] <- hi

  # Positions in [0,1] for gradientn's `values=`
  vals01 <- (stops - lo) / (hi - lo)

  # Named vector: names = colors, values = positions in [0,1]
  vals01
}
