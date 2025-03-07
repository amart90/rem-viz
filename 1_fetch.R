p1_fetch_targets <- list(
  # https://www.sciencebase.gov/catalog/item/620de574d34e6c7e83baa0d6
  tar_target(
    p1_estes_dem_tif,
    download_files(
      url = paste0(
        "https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1m/",
        "Projects/CO_DRCOG_2020_B20/TIFF/",
        "USGS_1M_13_x44y448_CO_DRCOG_2020_B20.tif"
      ),
      dest_folder = "1_fetch/out/",
      overwrite = TRUE
    ),
    format = "file"
  ),

  tar_target(
    p1_estes_nhdhr_zip,
    download_files(
      url = paste0(
        "https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/",
        "NHDPlusHR/VPU/Current/GPKG/NHDPLUS_H_1019_HU4_GPKG.zip"
      ),
      dest_folder = "1_fetch/out/",
      overwrite = TRUE
    ),
    format = "file"
  )
)
