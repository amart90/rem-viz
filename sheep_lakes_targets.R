sheep_lakes_targets <- list(
  tar_target(
    p2_sheeplakes_aoi_latlon,
    data.frame(
      lon = c(-105.604633, -105.625647),
      lat = c(40.403237, 40.397307)
    )
  ),

  tar_terra_rast(
    p2_sheeplakes_dem,
    crop_tif(
      dem_tif = p1_estes_dem_tif,
      lat_lon_df = p2_sheeplakes_aoi_latlon,
      scale = 10 / 8,
      offset_frac = 0.1
    )
  ),

  tar_terra_rast(
    p2_sheeplakes_dem_resample,
    resample_by_factor(
      dem_rast = p2_sheeplakes_dem,
      resample_factor = 2
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
      out_crs = terra::crs(p2_sheeplakes_dem),
      ReachCode_filter = c(
        "10190006000090",
        "10190006000091",
        "10190006000089",
        "10190006000089"
      )
    )
  ),

  tar_terra_rast(
    p2_sheeplakes_rem_rast,
    build_rem(
      dem = p2_sheeplakes_dem_resample,
      flowlines = p2_sheeplakes_flowlines,
      n_stream_pts = 600,
      refine_line = TRUE,
      refine_params = list(buffer = 10, stream_quantile = 0.93)
    )
  ),

  tar_map(
    # fmt: skip
    values = tibble(
      names = c("maiz", "concha", "aurora", "frida", "taurus1", "taurus2",
                "tierra", "bw", "taurus1_rev", "concha_rev", "maiz_rev"),
      pal = list(
        maiz =        c("#FFFFFF", "#9BC3C9", "#7CB0C1", "#3D72A2", "#144979",
                        "#003464"),
        concha =      c("#FFFFFF", "#D6D8D0", "#D4D5BF", "#708469", "#506446",
                        "#3D4D34", "#37402B", "#2A3326"),
        aurora =      c("#FFFFFF", "#E7C7A8", "#C29786", "#874D4A", "#5F2F2D",
                        "#3B141A", "#331718", "#27170B"),
        frida =       c("#FFFFFF", "#D6D8D0", "#A4ABB0", "#4C6C94", "#435E7F",
                        "#2F415F", "#232C43", "#0B1829"),
        taurus1 =     c("#FFFFFF", "#FCCC64", "#D4A43C", "#EF6F43", "#C7471B",
                        "#BC3112", "#660607", "#470607"),
        taurus2 =     c("#FFFFFF", "#A19E97", "#8F887A", "#7B7466", "#635C4A",
                        "#4E4735", "#37352E", "#23211A"),
        tierra =      c("#FFFFFF", "#CCC5C3", "#8D7E4F", "#7A6431", "#69542B",
                        "#573C22", "#4F330A", "#3B221A"),
        bw =          c("black", "black", "gray20", "gray40", "gray60",
                        "gray80", "white", "white"),
        taurus1_rev = c("#470607", "#470607", "#660607", "#BC3112", "#EF6F43",
                              "#FCCC64", "#FFFFFF", "#FFFFFF"),
        concha_rev =  c("#2A3326", "#2A3326", "#3D4D34", "#506446", "#D4D5BF",
                        "#D6D8D0", "#FFFFFF", "#FFFFFF"),
        maize_rev =   c("#003464", "#003464", "#144979", "#3D72A2", "#7CB0C1",
                        "#9BC3C9", "#FFFFFF", "#FFFFFF")
      ),
      grad_vals = list(
        maiz = c(0, 0.02, 0.05, 0.1, 0.15, 0.3, 1),
        concha = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        aurora = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        frida = c(0, 0.01, 0.03, 0.06, 0.11, 0.15, 0.2, 0.3, 1) ,
        taurus1 = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        taurus2 = c(0, 0.01, 0.03, 0.06, 0.11, 0.15, 0.2, 0.3, 1) ,
        tierra = c(0, 0.0001, 0.01, 0.1, 0.12, 0.2, 0.22, 0.4, 1),
        bw = c(0, 0.01, 0.03, 0.06, 0.11, 0.15, 0.2, 0.3, 1),
        taurus1_rev = c(0, 0.01, 0.03, 0.06, 0.11, 0.15, 0.2, 0.3, 1),
        concha_rev = c(0, 0.01, 0.03, 0.06, 0.11, 0.15, 0.2, 0.3, 1),
        maiz_rev = c(0, 0.01, 0.03, 0.06, 0.11, 0.15, 0.2, 0.3, 1)
      ),
      bg_col = purrr::map_chr(pal, \(x) tail(x, 1)),
      text_col = c("white", "white", "white", "white", "white",
                   "white", "white", "black", "black", "black",
                   "black")
    ),

    tar_target(
      p3_sheeplake_rem_plot,
      plot_rem(
        rem_rast = p2_sheeplakes_rem_rast[["rem"]],
        # fmt: skip
        pal = pal,
        grad_vals = grad_vals,
        lower_clamp = -0.1,
        upper_clamp = 4.5
      )
    ),

    # tar_target(
    #   p3_sheeplake_print_8_10_border_png,
    #   generate_print(
    #     rem_plot = p3_sheeplake_rem_plot,
    #     rem_rast = p2_sheeplakes_rem_rast,
    #     out_path = sprintf("3_visualize/out/sheeplake_%s_11_14.png", names),
    #     label_text = "Fall River at Sheep Lakes   |   Rock Mountain National Park",
    #     output_width = 14,
    #     output_height = 11,
    #     h_margins = 2,
    #     top_margin = 1.5,
    #     label_y = 3,
    #     bg_col = bg_col,
    #     text_col = text_col
    #   )
    # ),

    tar_target(
      p3_sheeplake_print_8_10_png,
      generate_print(
        rem_plot = p3_sheeplake_rem_plot,
        rem_rast = p2_sheeplakes_rem_rast,
        out_path = sprintf(
          "3_visualize/out/sheeplake_%s_8_10_cmyk.jpeg",
          names
        ),
        label_text = "Fall River at Sheep Lakes   |   Rock Mountain National Park",
        output_width = 10.5,
        output_height = 8.5,
        h_margins = 0.25,
        top_margin = 0.25,
        label_y = 1.75,
        bg_col = bg_col,
        text_col = text_col
      )
    ),

    names = names
  )
)
