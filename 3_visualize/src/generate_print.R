generate_print <- function(
  rem_plot,
  rem_rast,
  label_text,
  out_path,
  output_width = 17,
  output_height = 11,
  h_margins = 1,
  top_margin = 3,
  label_y = NULL,
  bg_col = "white",
  text_col = "black"
) {
  plot_scale <- terra::nrow(rem_rast) / terra::ncol(rem_rast)
  plot_width <- output_width - (2 * h_margins)
  plot_height <- plot_width * plot_scale
  label_y <- label_y %||% (output_height - top_margin - plot_height - 0.15)

  sysfonts::font_add_google(name = "Raleway", regular.wt = 300)
  showtext::showtext_auto()

  plot_out <- cowplot::ggdraw(
    xlim = c(0, output_width),
    ylim = c(0, output_height)
  ) +
    cowplot::draw_plot(
      rem_plot,
      x = h_margins,
      y = output_height - top_margin,
      width = plot_width,
      height = plot_height,
      hjust = 0,
      vjust = 1
    ) +
    cowplot::draw_label(
      label = label_text,
      x = output_width / 2,
      y = label_y,
      vjust = 1,
      fontfamily = "Raleway",
      size = 48,
      color = text_col
    ) +
    ggplot2::theme_void()

  cowplot::ggsave2(
    out_path,
    plot = plot_out,
    width = output_width,
    height = output_height,
    units = "in",
    bg = bg_col,
    dpi = 320
  )

  return(out_path)
}
