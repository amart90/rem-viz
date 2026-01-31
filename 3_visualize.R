p3_targets <- list(
  tar_target(
    p3_bowen_gulch_rem_plot,
    build_rem_plot(
      rem_rast = terra::rast(p2_bowen_gulch_rem_tif),
      pal = c("#003464", "#ffffff", "#003464"),
      grad_vals = c(-6, 0, 1.6),
      val_units = "absolute",
      interactive = FALSE
    )
  )
)
