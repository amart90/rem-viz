p1_fetch_targets <- list(
  tarchetypes::tar_map(
    values = tibble::tribble(
      ~dem      , ~url                                                                                          ,
      "x41y447" , "CO_NorthwestCO_2020_D20/TIFF/USGS_1M_13_x41y447_CO_NorthwestCO_2020_D20.tif"                 ,
      "x42y446" , "CO_NorthwestCO_2020_D20/TIFF/USGS_1M_13_x42y446_CO_NorthwestCO_2020_D20.tif"                 ,
      "x42y447" , "CO_NorthwestCO_2020_D20/TIFF/USGS_1M_13_x42y447_CO_NorthwestCO_2020_D20.tif"                 ,
      "x42y448" , "CO_NorthwestCO_2020_D20/TIFF/USGS_1M_13_x42y448_CO_NorthwestCO_2020_D20.tif"                 ,
      "x43y447" , "CO_NorthwestCO_2020_D20/TIFF/USGS_1M_13_x43y447_CO_NorthwestCO_2020_D20.tif"                 ,
      "x44y447" , "CO_DRCOG_2020_B20/TIFF/USGS_1M_13_x44y447_CO_DRCOG_2020_B20.tif"                             ,
      "x44y448" , "CO_DRCOG_2020_B20/TIFF/USGS_1M_13_x44y448_CO_DRCOG_2020_B20.tif"                             ,
      "x45y447" , "CO_DRCOG_2020_B20/TIFF/USGS_1M_13_x45y447_CO_DRCOG_2020_B20.tif"                             ,
      "x46y450" , "CO_CameronPeakWildfire_2021_D21/TIFF/USGS_1M_13_x46y450_CO_CameronPeakWildfire_2021_D21.tif" ,
      "x48y448" , "CO_CameronPeakWildfire_2021_D21/TIFF/USGS_1M_13_x48y448_CO_CameronPeakWildfire_2021_D21.tif" ,
      "x49y448" , "CO_CameronPeakWildfire_2021_D21/TIFF/USGS_1M_13_x49y448_CO_CameronPeakWildfire_2021_D21.tif" ,
      "x49y449" , "CO_SoPlatteRiver_Lot2a_2013/TIFF/USGS_one_meter_x49y449_CO_SoPlatteRiver_Lot2a_2013.tif"     ,
      "x50y448" , "CO_SoPlatteRiver_Lot2a_2013/TIFF/USGS_one_meter_x50y448_CO_SoPlatteRiver_Lot2a_2013.tif"     ,
      "x51y448" , "CO_EasternColorado_2018_A18/TIFF/USGS_1M_13_x51y448_CO_EasternColorado_2018_A18.tif"         ,
      "x52y448" , "CO_EasternColorado_2018_A18/TIFF/USGS_1M_13_x52y448_CO_EasternColorado_2018_A18.tif"
    ) |>
      dplyr::mutate(
        url = paste0(
          "https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1m/Projects/",
          url
        )
      ),
    tar_target(
      p1_dem_tif,
      download_files(url = url, dest_folder = "1_fetch/out/", overwrite = TRUE),
      format = "file"
    ),
    names = dem
  ),

  tar_target(
    p1_3dhp_gpkg,
    "1_fetch/in/noco_hydro.gpkg",
    format = "file"
  )

  # tar_target(
  #   p1_estes_nhdhr_zip,
  #   download_files(
  #     url = paste0(
  #       "https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/",
  #       "NHDPlusHR/VPU/Current/GPKG/NHDPLUS_H_1019_HU4_GPKG.zip"
  #     ),
  #     dest_folder = "1_fetch/out/",
  #     overwrite = TRUE
  #   ),
  #   format = "file"
  # )
)
