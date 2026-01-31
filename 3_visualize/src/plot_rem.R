plot_rem <- function(
  rem_rast,
  pal,
  grad_vals,
  lower_clamp = -Inf,
  upper_clamp = Inf,
  val_units = c("absolute", "relatve")
) {
  units <- rlang::arg_match(val_units, c("absolute", "relatve"))
  rem_df <- terra::clamp(
    rem_rast$rem,
    lower = lower_clamp,
    upper = upper_clamp
  ) |>
    terra::as.data.frame(xy = TRUE)

  if (val_units == "absolute") {
    rem_df$rem2 <- scales::rescale(rem_df$rem, from = range(rem_df$rem))
    grad_vals2 <- scales::rescale(grad_vals)
  }

  ggplot2::ggplot() +
    ggplot2::geom_tile(data = rem_df, aes(x = x, y = y, fill = rem2)) +
    #tidyterra::geom_spatraster(data = rem_df) +
    ggplot2::scale_fill_gradientn(colors = pal, values = grad_vals2) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "none")
}

build_rem_plot <- function(
  rem_rast,
  pal,
  grad_vals,
  val_units = c("absolute", "relative"),
  interactive = interactive()
) {
  rem <- terra::clamp(
    rem_rast$rem,
    lower = min(grad_vals),
    upper = max(grad_vals)
  )

  if (val_units == "absolute") {
    grad_vals_rescale <- scales::rescale(grad_vals)
  } else {
    grad_vals_rescale <- grad_vals
  }

  if (interactive) {
    plot_function <- tidyterra::geom_spatraster(data = rem)
  } else {
    rem <- terra::as.data.frame(rem, xy = TRUE)
    plot_function <- ggplot2::geom_tile(
      data = rem,
      aes(x = x, y = y, fill = rem)
    )
  }

  ggplot2::ggplot() +
    plot_function +
    ggplot2::scale_fill_gradientn(
      colors = pal,
      values = grad_vals_rescale,
      limits = range(grad_vals)
    ) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "none")
}
