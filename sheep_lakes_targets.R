sheep_lakes_targets <- list(
  tar_target(
    p2_sheeplakes_aoi_latlon,
    data.frame(
      lon = c(-105.607670, -105.626282),
      lat = c(40.403629, 40.399073)
    )
  ),

  tar_terra_rast(
    p2_sheeplakes_dem,
    crop_tif(
      dem_tif = p1_estes_dem_tif,
      lat_lon_df = p2_sheeplakes_aoi_latlon
    )
  ),

  tar_terra_vect(
    p2_sheeplakes_flowlines,
    crop_flowlines(
      flowline_path = paste0(
        "/vsizip/",
        p1_estes_nhdhr_zip,
        "/NHDPLUS_H_1019_HU4_GPKG.gpkg"
      ),
      layer = "NHDFlowline",
      line_crs = "EPSG:4269",
      lat_lon_df = p2_sheeplakes_aoi_latlon,
      out_crs = terra::crs(p2_sheeplakes_dem)
    )
  ),

  tar_terra_rast(
    p2_sheeplakes_rem_rast,
    build_rem(
      dem = p2_sheeplakes_dem,
      flowlines = p2_sheeplakes_flowlines,
      n_stream_pts = 600,
      refine_line = TRUE,
      refine_params = list(buffer = 10, stream_quantile = 0.93)
    )
  ),

  tar_target(
    p3_sheeplakes_pals,
    # fmt: skip
    tibble::tibble(
      names = c("maiz", "concha", "aurora", "frida", "naturaleza", "taurus1",
                "taurus2", "tierra"),
      pal = list(
        maiz =       c("#FFFFFF", "#9BC3C9", "#7CB0C1", "#3D72A2", "#144979",
                       "#003464"),
        concha =     c("#FFFFFF", "#D6D8D0", "#D4D5BF", "#708469", "#506446",
                       "#3D4D34", "#37402B", "#2A3326"),
        aurora =     c("#FFFFFF", "#E7C7A8", "#C29786", "#874D4A", "#5F2F2D",
                       "#3B141A", "#331718", "#27170B"),
        frida =      c("#FFFFFF", "#D6D8D0", "#A4ABB0", "#4C6C94", "#435E7F",
                       "#2F415F", "#232C43", "#0B1829"),
        naturaleza = c("#FFFFFF", "#FAF7D2", "#E1CA89", "#BE852C", "#99300C",
                       "#80100C", "#660607", "#470607"),
        taurus1 =    c("#FFFFFF", "#FCCC64", "#D4A43C", "#EF6F43", "#C7471B",
                       "#BC3112", "#660607", "#470607"),
        taurus2 =    c("#FFFFFF", "#A19E97", "#8F887A", "#7B7466", "#635C4A",
                       "#4E4735", "#37352E", "#23211A"),
        tierra =     c("#FFFFFF", "#CCC5C3", "#8D7E4F", "#7A6431", "#69542B",
                       "#573C22", "#4F330A", "#3B221A")
      ),
      grad_vals = list(
        maiz = c(0, 0.02, 0.05, 0.1, 0.15, 0.3, 1),
        concha = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        aurora = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        frida = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        naturaleza = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        taurus1 = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        taurus2 = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        tierra = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1)
      )
    )
  ),

  tar_target(
    p3_sheeplake_rem_plots,
    plot_rem(
      rem_rast = p2_sheeplakes_rem_rast[["rem"]],
      # fmt: skip
      pal = unlist(p3_sheeplakes_pals$pal),
      grad_vals = unlist(p3_sheeplakes_pals$grad_vals),
      lower_clamp = 0,
      upper_clamp = 4.5
    ),
    pattern = map(p3_sheeplakes_pals),
    iteration = "list"
  ),

  tar_target(
    p3_sheeplake_rem_plot,
    plot_rem(
      rem_rast = p2_sheeplakes_rem_rast[["rem"]],
      # fmt: skip
      pal = c("white", "#FCCC64", "#D4A43C", "#EF6F43", "#C7471B",
              "#BC3112", "#660607", "#470607"),
      grad_vals = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
      lower_clamp = 0,
      upper_clamp = 4.5
    )
  )
)
