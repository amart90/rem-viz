# install.packages(c("terra","classInt","scales","farver"))
library(terra)
library(classInt)
library(scales)
library(farver)

# --- your leaner scale generator (slightly refactored to reuse inside optimizer) ---
auto_rem_values <- function(
  rem,
  method = c("quantile_power", "jenks"),
  n_stops = 15,
  upper_clamp_q = 0.90,
  lower_clamp_q = NULL,
  transform = c("asinh", "log1p", "none"),
  power = 2.2,
  palette = NULL,
  cold_low_anchor = TRUE,
  seed = 42
) {
  stopifnot(inherits(rem, "SpatRaster"))
  method <- match.arg(method)
  transform <- match.arg(transform)
  set.seed(seed)

  v <- values(rem, mat = FALSE)
  v <- v[is.finite(v)]
  if (!length(v)) stop("No finite values in REM.")

  lo <- if (is.null(lower_clamp_q)) min(v, na.rm = TRUE) else
    as.numeric(quantile(v, lower_clamp_q, na.rm = TRUE))
  hi <- as.numeric(quantile(v, upper_clamp_q, na.rm = TRUE))
  if (!is.finite(lo) || !is.finite(hi) || lo >= hi)
    stop("Bad clamp limits; check quantiles.")
  v_clip <- pmin(pmax(v, lo), hi)

  tf <- switch(
    transform,
    "none" = identity,
    "log1p" = function(x) ifelse(x - lo >= 0, log1p(x - lo), -log1p(lo - x)),
    "asinh" = function(x) asinh(x - lo)
  )
  itf <- switch(
    transform,
    "none" = identity,
    "log1p" = function(y) ifelse(y >= 0, lo + expm1(y), lo - expm1(-y)),
    "asinh" = function(y) lo + sinh(y)
  )

  vt <- tf(v_clip)

  if (method == "quantile_power") {
    p <- seq(0, 1, length.out = n_stops)
    pu <- p^power
    stt <- as.numeric(quantile(vt, probs = pu, na.rm = TRUE, names = FALSE))
    stt <- sort(unique(stt))
    stt[1] <- min(vt, na.rm = TRUE)
    stt[length(stt)] <- max(vt, na.rm = TRUE)
  } else {
    ci <- classInt::classIntervals(
      vt,
      n = max(3, n_stops - 1L),
      style = "fisher"
    )
    br <- sort(unique(ci$brks))
    mids <- (head(br, -1) + tail(br, -1)) / 2
    stt <- sort(unique(c(br[1], mids, br[length(br)])))
    stt <- sort(unique(stats::quantile(
      stt,
      probs = seq(0, 1, length.out = n_stops),
      names = FALSE
    )))
  }

  stops <- itf(stt)
  stops[1] <- lo
  stops[length(stops)] <- hi
  vals01 <- (stops - lo) / (hi - lo)

  if (is.null(palette)) {
    base_pal <- viridis_pal()(max(6, length(vals01) - 2))
    palette <- if (cold_low_anchor) c("#1d3557", "#457b9d", base_pal) else
      base_pal
  }
  if (length(palette) != length(vals01)) {
    palette <- colorRampPalette(palette)(length(vals01))
  }

  out <- vals01
  names(out) <- palette
  attr(out, "limits") <- c(lo, hi)
  out
}

# --- 1) channel proxy via DoG valley detector + low-quantile gate ---
channel_mask <- function(
  rem,
  sigma_small = 1.5,
  sigma_large = 4.5,
  low_q = 0.35
) {
  # Gaussian blur via separable box-approx (terra focal with weighted kernel)
  gkern <- function(sigma) {
    r <- max(1, ceiling(3 * sigma))
    x <- -r:r
    w <- exp(-(x^2) / (2 * sigma^2))
    w / sum(w)
  }
  # separable: horizontal then vertical
  blur <- function(r, sigma) {
    k <- gkern(sigma)
    r1 <- focal(
      r,
      w = matrix(k, nrow = 1),
      fun = sum,
      na.policy = "omit",
      na.rm = TRUE,
      pad = TRUE
    )
    r2 <- focal(
      r1,
      w = matrix(k, ncol = 1),
      fun = sum,
      na.policy = "omit",
      na.rm = TRUE,
      pad = TRUE
    )
    r2
  }
  s <- blur(rem, sigma_small)
  l <- blur(rem, sigma_large)
  dog <- s - l # negative = darker valleys at small scale

  # low-quantile of REM values (not assuming non-negativity)
  v <- values(rem, mat = FALSE)
  v <- v[is.finite(v)]
  thr <- as.numeric(quantile(v, probs = low_q, na.rm = TRUE))
  low_gate <- rem <= thr

  # valley pixels: negative DoG AND low values
  mask <- (dog < 0) & (low_gate)
  mask
}

# --- 2) evaluation metric: luminance contrast in LAB ---
score_palette <- function(rem, vec_values, mask, sample_n = 200000) {
  # vec_values: named vector (names=hex colors, values in [0,1]); limits in attribute
  lims <- attr(vec_values, "limits")
  lo <- lims[1]
  hi <- lims[2]

  # sample pixels for speed
  set.seed(1)
  v <- values(rem, mat = FALSE)
  ok <- is.finite(v)
  idx <- which(ok)
  if (length(idx) > sample_n) idx <- sample(idx, sample_n)

  vals <- v[idx]
  vals <- pmin(pmax(vals, lo), hi)
  pos <- (vals - lo) / (hi - lo)

  # interpolate colors along the gradient stops
  # Build a color ramp function from stops
  stops_pos <- unname(vec_values)
  stops_col <- names(vec_values)
  col_fun <- grDevices::colorRamp(stops_col, space = "Lab") # interpolate in Lab space
  rgb_mat <- col_fun(pos) / 255
  hex_vec <- grDevices::rgb(rgb_mat[, 1], rgb_mat[, 2], rgb_mat[, 3])

  # Convert to LAB and take L*
  lab <- farver::convert_colour(t(col2rgb(hex_vec)), from = "rgb", to = "lab")
  L <- lab[, 1]

  # channel vs non-channel sets
  mvals <- values(mask, mat = FALSE)
  m_idx <- which(mvals)[idx %in% which(mvals)] # align
  in_mask <- rep(FALSE, length(idx))
  in_mask[idx %in% which(mvals)] <- TRUE

  if (!any(in_mask) || all(in_mask)) return(-Inf) # degenerate mask

  L_in <- L[in_mask]
  L_out <- L[!in_mask]

  # Contrast (want channels darker, i.e., lower L*)
  delta <- mean(L_out, na.rm = TRUE) - mean(L_in, na.rm = TRUE)

  # Add a small edge sharpness term: std dev ratio (optional)
  # Here we just use pooled sd penalty to prefer tighter channel luminance
  tightness <- -sd(L_in, na.rm = TRUE) * 0.05

  delta + tightness
}

# --- 3) optimizer: small grid search over your main knobs ---
optimize_rem_palette <- function(
  rem,
  method = "quantile_power",
  n_stops = 15,
  powers = c(1.6, 2.0, 2.4, 2.8),
  upper_qs = c(0.86, 0.90, 0.94, 0.97),
  transforms = c("asinh", "log1p", "none"),
  palettes = list(
    cool_viridis = NULL, # default inside auto_rem_values
    viridis_only = function(n) viridisLite::viridis()(n_stops),
    cividis_only = function(n) viridisLite::cividis()(n_stops)
  ),
  mask_low_q = 0.35,
  sigma_small = 1.5,
  sigma_large = 4.5,
  sample_n = 200000
) {
  browser()
  m <- channel_mask(
    rem,
    sigma_small = sigma_small,
    sigma_large = sigma_large,
    low_q = mask_low_q
  )

  best <- list(score = -Inf)
  for (U in upper_qs)
    for (T in transforms)
      for (P in powers) {
        for (pal_name in names(palettes)) {
          pal_fun <- palettes[[pal_name]]

          vec <- auto_rem_values(
            rem,
            method = method,
            n_stops = n_stops,
            upper_clamp_q = U,
            lower_clamp_q = NULL,
            transform = T,
            power = P,
            palette = if (is.null(pal_fun)) NULL else pal_fun(n_stops),
            cold_low_anchor = is.null(pal_fun) # only add cold anchor for default set
          )

          s <- score_palette(rem, vec, m, sample_n = sample_n)
          if (is.finite(s) && s > best$score) {
            best <- list(
              score = s,
              vec = vec,
              params = list(
                upper_clamp_q = U,
                transform = T,
                power = P,
                palette = pal_name
              )
            )
          }
        }
      }
  best
}


#How to run it
# rem <- rast("path/to/your_rem.tif")
targets::tar_load(p2_sheeplakes_rem_rast)
res <- optimize_rem_palette(
  p2_sheeplakes_rem_rast$rem,
  n_stops = 15,
  powers = c(1.6, 2.0, 2.4, 2.8),
  upper_qs = c(0.86, 0.90, 0.94, 0.97),
  transforms = c("asinh", "log1p", "none")
)

# Use the optimized values/limits directly in ggplot:
vec <- res$vec
ggplot() +
  tidyterra::geom_spatraster(data = rem) +
  scale_fill_gradientn(
    colours = names(vec),
    values = unname(vec),
    limits = attr(vec, "limits"),
    oob = scales::squish
  ) +
  coord_sf(expand = FALSE) +
  theme_minimal()

res$params # <- shows which settings it chose
res$score # <- objective value (higher = more channel pop)
