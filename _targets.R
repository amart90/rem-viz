# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(geotargets)
library(tarchetypes)
library(tibble)

# Set target options:
tar_option_set(
  packages = c("curl", "terra", "flowdem", "cli", "tidyterra", "ggplot2"),
  format = "qs"
)

# Run the R scripts in the R/ folder with your custom functions:
tar_source(c("1_fetch/src", "2_process/src", "3_visualize/src"))
source("1_fetch.R")
source("fall_river_targets.R")
source("sheep_lakes_targets.R")

# Replace the target list below with your own:
c(p1_fetch_targets, sheep_lakes_targets)
