plot_rem <- function(
  rem_rast,
  pal,
  grad_vals,
  lower_clamp = -Inf,
  upper_clamp = Inf
) {
  rem_df <- terra::clamp(
    rem_rast$rem,
    lower = lower_clamp,
    upper = upper_clamp
  ) |>
    terra::as.data.frame(xy = TRUE)

  ggplot2::ggplot() +
    ggplot2::geom_tile(data = rem_df, aes(x = x, y = y, fill = rem)) +
    ggplot2::scale_fill_gradientn(colors = pal, values = grad_vals) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "none")
}
