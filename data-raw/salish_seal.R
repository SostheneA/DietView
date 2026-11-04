# Build the DNA metabarcoding example datasets shipped with DietView:
# salish_seal_dna and salish_seal_lineage (data/*.rda).
#
# Source: "Main Dataset: Harbour Seal DNA Diet Data" (Thomas et al. 2022,
# figshare, doi:10.6084/m9.figshare.12043173, CC0 1.0), the data of the Data
# Descriptor: Thomas, A. C. et al. (2022) Data on the diets of Salish Sea
# harbour seals from DNA metabarcoding. Scientific Data 9: 68,
# doi:10.1038/s41597-022-01152-5. A copy of the file is in data-raw/salish/.
#
# The lineage is resolved once against WoRMS with DietView itself and frozen.
# Assignments that DNA could not split ("A OR B") are placed at the finest
# rank the candidate species share (their genus, or a coarser rank).
#
# Run from the package root:  Rscript data-raw/salish_seal.R

devtools::load_all(".")
raw <- read.csv(file.path("data-raw", "salish", "Harbour_Seal_DNA_Diet_Data.csv"),
                stringsAsFactors = FALSE, na.strings = c("NA", ""))

# "Sebastes_caurinus_OR _Sebastes_maliger" -> "Sebastes caurinus OR Sebastes maliger"
clean_label <- function(x) {
  parts <- strsplit(x, "_?OR_?", perl = TRUE)
  vapply(parts, function(p) paste(trimws(gsub("_", " ", p)), collapse = " OR "), "")
}

salish_seal_dna <- data.frame(
  sample_id     = raw$sample_ID,
  predator      = raw$predator,
  site          = raw$site,
  lat           = raw$Lat,
  lon           = raw$Lon,
  year          = as.integer(raw$year),
  month         = as.integer(raw$month),
  season        = factor(c("winter", "winter", "spring", "spring", "spring", "summer",
                           "summer", "summer", "autumn", "autumn", "autumn",
                           "winter")[raw$month],
                         levels = c("winter", "spring", "summer", "autumn")),
  lab           = raw$Lab,
  prey_label    = clean_label(raw$prey_ID),
  common_name   = trimws(gsub("_", " ", raw$common_name)),
  reads_16S     = as.integer(raw$count.16S),
  reads_COI     = as.integer(raw$count.COI),
  diet_fraction = raw$DNA_diet_fraction,
  stringsAsFactors = FALSE
)

# ---- lineage: one WoRMS lookup per candidate species --------------------------
ranks <- c("kingdom", "phylum", "class", "order", "family", "genus", "species")
labels <- sort(unique(salish_seal_dna$prey_label))
cands <- strsplit(labels, " OR ", fixed = TRUE)
species <- sort(unique(unlist(cands)))
keys <- data.frame(prey_id = NA_integer_, prey_name = species)
lin <- dv_taxonomy_worms(keys, ranks = ranks, cache_dir = NULL, fuzzy = TRUE)
stopifnot(all(lin$match_type %in% c("exact", "fuzzy")))
print(lin[lin$match_type != "exact", c("prey_name", "matched_name")])

shared <- function(sp) {
  rows <- lin[match(sp, lin$prey_name), ranks, drop = FALSE]
  out <- stats::setNames(rep(NA_character_, length(ranks)), ranks)
  for (r in ranks) {
    v <- unique(rows[[r]])
    if (length(v) == 1L && !is.na(v)) out[[r]] <- v else break
  }
  out
}
salish_seal_lineage <- data.frame(prey_label = labels, stringsAsFactors = FALSE)
L <- t(vapply(cands, shared, character(length(ranks))))
for (r in ranks) salish_seal_lineage[[r]] <- L[, r]
salish_seal_lineage$n_candidates <- lengths(cands)
salish_seal_lineage$aphia_id <- ifelse(
  lengths(cands) == 1L, lin$aphia_used[match(labels, lin$prey_name)], NA_integer_)

usethis::use_data(salish_seal_dna, salish_seal_lineage, overwrite = TRUE, compress = "xz")
