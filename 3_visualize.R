p3_targets <- list(
  tar_target(
    p3_bowen_gulch_rem_plot_blue,
    build_rem_plot(
      rem_rast = terra::rast(p2_bowen_gulch_rem_tif),
      pal = c(
        "#06162F",
        "#1957AC",
        "#6CEDFF",
        "#ffffff",
        "#6CEDFF",
        "#1957AC",
        "#06162F"
      ),
      grad_vals = c(-6, -1.5, -0.5, 0, 0.1, 0.5, 1.6),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_bowen_gulch_rem_plot_red,
    build_rem_plot(
      rem_rast = terra::rast(p2_bowen_gulch_rem_tif),
      pal = c(
        "#300000",
        "#FF4D00",
        "#FFE261",
        "#FFFCE2",
        "#FFE261",
        "#FF4D00",
        "#300000"
      ),
      grad_vals = c(-6, -1.0, -0.2, 0, 0.1, 0.5, 1.6),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_bowen_gulch_rem_plot_green,
    build_rem_plot(
      rem_rast = terra::rast(p2_bowen_gulch_rem_tif),
      pal = c(
        "#1A2600",
        "#3C7A24",
        "#E8E1A7",
        "#FDFDF2",
        "#E8E1A7",
        "#3C7A24",
        "#1A2600"
      ),
      grad_vals = c(-6, -1.0, -0.01, 0, 0.1, 0.5, 1.6),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_s_kawuneeche_rem_plot_blue,
    build_rem_plot(
      rem_rast = terra::rast(p2_s_kawuneeche_rem_tif),
      pal = c(
        "#06162F",
        "#1957AC",
        "#6CEDFF",
        "#ffffff",
        "#6CEDFF",
        "#1957AC",
        "#06162F"
      ),
      grad_vals = c(-4, -1, -0.5, 0, 0.1, 0.7, 2.4),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_s_kawuneeche_rem_plot_red,
    build_rem_plot(
      rem_rast = terra::rast(p2_s_kawuneeche_rem_tif),
      pal = c(
        "#300000",
        "#FF4D00",
        "#FFE261",
        "#FFFCE2",
        "#FFE261",
        "#FF4D00",
        "#300000"
      ),
      grad_vals = c(-4, -1, -0.5, 0, 0.1, 0.7, 2.4),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_s_kawuneeche_rem_plot_green,
    build_rem_plot(
      rem_rast = terra::rast(p2_s_kawuneeche_rem_tif),
      pal = c(
        "#1A2600",
        "#3C7A24",
        "#E8E1A7",
        "#FDFDF2",
        "#E8E1A7",
        "#3C7A24",
        "#1A2600"
      ),
      grad_vals = c(-4, -1, -0.05, 0, 0.1, 0.7, 2.4),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_moraine_park_rem_plot_blue,
    build_rem_plot(
      rem_rast = terra::rast(p2_moraine_park_rem_tif),
      pal = c(
        "#06162F",
        "#1957AC",
        "#6CEDFF",
        "#ffffff",
        "#6CEDFF",
        "#1957AC",
        "#06162F"
      ),
      grad_vals = c(-2, -1, -0.1, 0, 0.05, 0.4, 1),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_moraine_park_rem_plot_red,
    build_rem_plot(
      rem_rast = terra::rast(p2_moraine_park_rem_tif),
      pal = c(
        "#300000",
        "#FF4D00",
        "#FFE261",
        "#FFFCE2",
        "#FFE261",
        "#FF4D00",
        "#300000"
      ),
      grad_vals = c(-2, -1, -0.1, 0, 0.05, 0.4, 1),
      val_units = "absolute",
      interactive = FALSE
    )
  ),

  tar_target(
    p3_moraine_park_rem_plot_green,
    build_rem_plot(
      rem_rast = terra::rast(p2_moraine_park_rem_tif),
      pal = c(
        "#1A2600",
        "#3C7A24",
        "#E8E1A7",
        "#FDFDF2",
        "#E8E1A7",
        "#3C7A24",
        "#1A2600"
      ),
      grad_vals = c(-2, -1, -0.1, 0, 0.05, 0.3, 1),
      val_units = "absolute",
      interactive = FALSE
    )
  )
)
