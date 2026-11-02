# =============================================================================
# DietView: end-to-end demo starting from BASE data (no taxonomy columns)
# Shows the package adding taxa, then writing a standalone HTML dashboard.
# =============================================================================
library(DietView)

ext <- function(f) system.file("extdata", f, package = "DietView", mustWork = TRUE)

# 1. Load the BASE long table (14 columns, NO kingdom..species) ---------------
dat <- read.csv(ext("dietview_example.csv"), stringsAsFactors = FALSE,
                na.strings = c("NA", ""))
str(dat)

# 2. Declare column roles -----------------------------------------------------
spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",
  prey_name      = "verified_name",
  weight         = "prey_weight",
  count          = NULL,                 # occurrence = one appearance per record
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)

# 3. ADD TAXA -----------------------------------------------------------------
# (a) Offline / reproducible: join a lineage lookup table you supply.
lin  <- read.csv(ext("dietview_example_lineage.csv"), stringsAsFactors = FALSE,
                 na.strings = c("NA", ""))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin)

# (b) Real use: fetch from WoRMS by AphiaID/name (needs 'worrms' + internet):
# prep <- dv_prepare(dat, spec, taxonomy = "worms")
print(prep)

# 4. Metrics: within-rank importance (NA included; each rank sums to 100) ------
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
print(dv_rank_table(tree, "Class"))
sum(dv_rank_table(tree, "Class")$pct_occ)   # 100

# 5. Figures + digestion diagnostic ------------------------------------------
dv_sunburst(tree, mode = "occurrence", title = "All predators")
dv_digestion_diagnostic(prep, by = "period")

# 6. Write the standalone dashboard -------------------------------------------
# tempdir() keeps the demo tidy; use your own folder to keep the file.
dv_deploy(prep, file = "dietview_dashboard.html", dir = tempdir(),
          strata = c("period", "size_class", "size_bin"),
          cross  = list(c("size_bin", "period")),   # length bins x period rows
          length_col = "somatic_length_cm")

# 7. Interactive app (optional) ----------------------------------------------
# run_dietview(prep)
