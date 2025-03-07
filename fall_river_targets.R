# https://apps.nationalmap.gov/downloader/
# https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1m/Projects/CO_DRCOG_2020_B20/TIFF/USGS_1M_13_x44y448_CO_DRCOG_2020_B20.tif

fall_river_targets <- list(
  tar_target(
    p2_fallriver_aoi_latlon,
    data.frame(
      lon = c(-105.633482, -105.640259),
      lat = c(40.411731, 40.408242)
    )
  ),

  tar_terra_rast(
    p2_fallriver_dem,
    crop_tif(
      dem_tif = p1_estes_dem_tif,
      lat_lon_df = p2_fallriver_aoi_latlon
    )
  ),

  tar_terra_vect(
    p2_fallriver_flowlines,
    crop_flowlines(
      flowline_path = paste0(
        "/vsizip/",
        p1_estes_nhdhr_zip,
        "/NHDPLUS_H_1019_HU4_GPKG.gpkg"
      ),
      layer = "NHDFlowline",
      line_crs = "EPSG:4269",
      lat_lon_df = p2_fallriver_aoi_latlon,
      out_crs = terra::crs(p2_sheeplakes_dem)
    )
  ),

  tar_terra_rast(
    p2_fallriver_rem_rast,
    build_rem(
      dem = p2_fallriver_dem,
      flowlines = p2_fallriver_flowlines,
      n_stream_pts = 600,
      refine_line = TRUE,
      refine_params = list(buffer = 10, stream_quantile = 0.93)
    )
  ),

  tar_target(
    p3_fallriver_rem_plot,
    plot_rem(
      rem_rast = p2_fallriver_rem_rast[["rem"]],
      # fmt: skip
      pal = c("white", "#FCCC64FF", "#D4A43CFF", "#EF6F43FF", "#C7471BFF",
              "#BC3112FF", "#660607FF", "#470607FF"),
      grad_vals = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
      lower_clamp = -Inf,
      upper_clamp = Inf
    )
  )
)
