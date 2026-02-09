p2_targets <- list(
  # Preprocessing ----
  tar_target(
    p2_sheeplakes_dem_resample_tif,
    resample_by_factor(
      dem_rast = crop_tif(
        dem_tif = p1_dem_tif_x44y448,
        lat_lon_df = data.frame(
          lon = c(-105.604633, -105.625647),
          lat = c(40.403237, 40.397307)
        ),
        scale = 10 / 8,
        offset_frac = 0.1
      ),
      resample_factor = 2,
      filename = "2_process/out/sheplakes_resample.tif"
    ),
    format = "file"
  ),

  # Individual REMs ----
  ## Sheep Lakes ----
  tar_target(
    p2_sheeplakes_rem_tif,
    build_rem_3dhp(
      dem_tif = p2_sheeplakes_dem_resample_tif,
      aoi_ext = NULL,
      flowlines_gpkg = p1_3dhp_gpkg,
      out_filename = "2_process/out/sheeplakes_rem.tif",
      n_stream_pts = 4400,
      max_points = 2200,
      flowline_gnisid = "177536",
    ),
    format = "file"
  ),

  ## South Kawuneeche Valley ----
  tar_target(
    p2_s_kawuneeche_rem_tif,
    build_rem_3dhp(
      dem_tif = p1_dem_tif_x42y446,
      aoi_ext = c(
        xmin = -105.871395,
        ymin = 40.253485,
        xmax = -105.847136,
        ymax = 40.286956
      ),
      flowlines_gpkg = p1_3dhp_gpkg,
      out_filename = "2_process/out/s_kawuneeche_rem.tif",
      n_stream_pts = 4400,
      max_points = 2200,
      flowline_gnisid = "45730"
    ),
    format = "file"
  ),

  ## Bowen Gulch ----
  tar_target(
    p2_bowen_gulch_rem_tif,
    build_rem_3dhp(
      dem_tif = p1_dem_tif_x42y447,
      aoi_ext = c(
        xmin = -105.867974,
        ymin = 40.315897,
        xmax = -105.851539,
        ymax = 40.331207
      ),
      flowlines_gpkg = p1_3dhp_gpkg,
      out_filename = "2_process/out/bowen_gulch_rem.tif",
      n_stream_pts = 4400,
      max_points = 2200,
      flowline_gnisid = "45730",
      flowline_id3dhp = "'1GZZW', '23KQ7', '2I49H','3KU6C', '4NKKL', '53PUZ', '56XE5', '58J2Z', '7H8DW', '8AP94', '8M1OV', 'FDB2R', 'FDB2W', 'G6I4I', '2TFIW', '334E0', '4KD38', 'F3K6S', 'FI5V4'"
    ),
    format = "file"
  ),

  ## Moraine Park ----
  tar_target(
    p2_moraine_park_rem_tif,
    build_rem_3dhp(
      dem_tif = c(p1_dem_tif_x44y447, p1_dem_tif_x45y447),
      aoi_ext = c(
        xmin = -105.617034,
        ymin = 40.346733,
        xmax = -105.595909,
        ymax = 40.357673
      ),
      flowlines_gpkg = p1_3dhp_gpkg,
      out_filename = "2_process/out/moraine_park_rem.tif",
      n_stream_pts = 4400,
      max_points = 2200,
      query_text = "onsurface = 1 AND id3dhp NOT IN ('C5Z6F', '1AY14', 'BRCJ4', 'GW8DC', '42ENW', 'Z3Yx', '4LS2P', '7KM50', '21S4B')"
    ),
    format = "file"
  )
)
