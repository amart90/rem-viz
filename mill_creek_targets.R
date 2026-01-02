millcreek_targets <- list(
  tar_target(
    p2_millcreek_aoi_latlon,
    data.frame(
      lon = c(-105.6142654, -105.5973077),
      lat = c(40.3410645, 40.3341061)
    )
  ),

  tar_terra_rast(
    p2_millcreek_dem,
    crop_tif(
      dem_tif = p1_dem_tif_x44y447,
      lat_lon_df = p2_millcreek_aoi_latlon
    )
  ),

  tar_terra_vect(
    p2_millcreek_flowlines,
    crop_flowlines(
      flowline_path = p1_3dhp_gpkg,
      layer = "flowlines",
      line_crs = "EPSG:26913",
      lat_lon_df = p2_millcreek_aoi_latlon,
      out_crs = terra::crs(p2_millcreek_dem)
    )
  ),

  tar_terra_rast(
    p2_millcreek_rem_rast,
    build_rem(
      dem = p2_millcreek_dem,
      flowlines = p2_millcreek_flowlines,
      n_stream_pts = 600,
      refine_line = TRUE,
      refine_params = list(buffer = 10, stream_quantile = 0.95)
    )
  ),

  tar_target(
    p3_millcreek_rem_plot,
    plot_rem(
      rem_rast = p2_millcreek_rem_rast[["rem"]],
      # fmt: skip
      pal = c("white", "#FCCC64FF", "#D4A43CFF", "#EF6F43FF", "#C7471BFF",
              "#BC3112FF", "#660607FF", "#470607FF"),
      grad_vals = c(0, 0.070, 0.079, 0.086, 0.106, 0.209, 0.471, 0.773, 1),
      #grad_vals = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
      lower_clamp = -Inf,
      upper_clamp = Inf
    )
  )
)
