#' Download files
#'
#' @param url chr; the url of the file(s) to download; can handle multiple files
#' @param dest_folder chr; path to the folder to write files to
#'
#' @return chr; paths to downloaded files
#'
download_files <- function(url, dest_folder, overwrite = FALSE) {
  # If dest_folder doesn't have a trailing slash, add one
  dest_folder <- ifelse(
    grepl("/$", dest_folder),
    dest_folder,
    paste0(dest_folder, "/")
  )

  # Built destination file paths
  dest_files <- paste0(dest_folder, basename(url))

  # Check if file exists
  if (any(file.exists(dest_files)) & !overwrite) {
    cli::cli_abort(c(
      "If {.code override = FALSE}, all files must not already exist.",
      x = "At least one file exists already.",
      i = "Set {.code override = FALSE} to re-download all files."
    ))
  }
  # Download file(s)
  curl::multi_download(url, dest_files)

  return(dest_files)
}
