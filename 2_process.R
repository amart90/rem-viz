p2_targets <- list(
  # Individuals ----
  # onahu_creek (not that great)
  # tar_target(
  #   p2_onahu_creek_rem_tif,
  #   build_rem_3dhp(
  #     dem_tif = p1_dem_tif_x42y447,
  #     aoi_ext = c(
  #       xmin = -105.8520462,
  #       ymin = 40.2933578,
  #       xmax = -105.8440229,
  #       ymax = 40.3187568
  #     ),
  #     flowlines_gpkg = p1_3dhp_gpkg,
  #     out_filename = "2_process/out/onahu_creek_rem.tif"
  #   ),
  #   format = "file"
  # ),

  # South Kawuneeche Valley
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
      out_filename = "2_process/out/s_kawuneeche_rem_4400_2200.tif",
      n_stream_pts = 4400,
      max_points = 2200
    ),
    format = "file"
  )

  # Full Scenes ----
  # tar_target(
  #   p2_grand_lake_n_rem_tif,
  #   build_rem_3dhp(
  #     dem_tif = p1_dem_tif_x42y447,
  #     aoi_ext = NULL,
  #     flowlines_gpkg = p1_3dhp_gpkg,
  #     n_stream_pts = 1800,
  #     out_filename = "2_process/out/grand_lake_x42y477_rem.tif"
  #   ),
  #   format = "file"
  # ),
  #
  # tar_target(
  #   p2_grand_lake_w_rem_tif,
  #   build_rem_3dhp(
  #     dem_tif = p1_dem_tif_x41y447,
  #     aoi_ext = NULL,
  #     flowlines_gpkg = p1_3dhp_gpkg,
  #     n_stream_pts = 1800,
  #     out_filename = "2_process/out/grand_lake_x41y477_rem.tif"
  #   ),
  #   format = "file"
  # ),
  #
  # tar_target(
  #   p2_grand_lake_s_rem_tif,
  #   build_rem_3dhp(
  #     dem_tif = p1_dem_tif_x42y446,
  #     aoi_ext = NULL,
  #     flowlines_gpkg = p1_3dhp_gpkg,
  #     n_stream_pts = 1800,
  #     out_filename = "2_process/out/grand_lake_x42y446_rem.tif"
  #   ),
  #   format = "file"
  # )
)
