# function(dem_tif, crop_ext) {}
#
# tar_load(p1_dem_tif_x42y447)
#
# dem_rast <- terra::rast(p1_dem_tif_x42y447)
#
# aoi_poly <- sf::st_read("1_fetch/in/rectangular_extents.geojson")[10, ] |>
#   sf::`st_crs<-`(4326) |>
#   sf::st_transform(terra::crs(dem_rast)) |>
#   terra::vect()
#
# onahu_creek_rast <- terra::crop(dem_rast, aoi_poly)
# terra::plot(onahu_creek_rast)
# terra::writeRaster(onahu_creek_rast, "onahu.tif")
