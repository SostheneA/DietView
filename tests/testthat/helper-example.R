example_data <- function() {
  f <- function(x) system.file("extdata", x, package = "DietView")
  list(dat = utils::read.csv(f("dietview_example.csv"), na.strings = c("NA", "")),
       lin = utils::read.csv(f("dietview_example_lineage.csv"), na.strings = c("NA", "")))
}
example_spec <- function(...) dv_spec(
  predator = "predator_species_common_name", stomach = "stomach_id",
  prey_id = "aphia_id", prey_name = "verified_name",
  weight = "prey_weight", digestion = "digestion_level_id", ...)
example_prep <- function() {
  e <- example_data()
  suppressMessages(dv_prepare(e$dat, example_spec(), taxonomy = "table",
                              lineage = e$lin, verbose = FALSE))
}
