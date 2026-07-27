#' DietView: taxonomically complete visualization of diet data
#'
#' DietView takes a long table of stomach-content records (one row per prey
#' record), resolves prey to the WoRMS classification, and renders the whole
#' diet as an interactive multi-rank sunburst. Relative importance is computed
#' in two currencies (occurrence and weight) as the share of each taxon within
#' its own taxonomic rank, keeping unidentified prey as an explicit "NA"
#' category so the identification gaps are visible rather than hidden. Any
#' number of covariates (period, year, size class, length bins, region, ...)
#' can stratify the views, and the identification bias linked to digestion
#' level is quantified explicitly.
#'
#' Main entry points: [dv_spec()], [dv_prepare()], [dv_build_tree()],
#' [dv_sunburst()], [dv_digestion_diagnostic()], [dv_build_html()],
#' [run_dietview()].
#'
#' @keywords internal
"_PACKAGE"

# The seven flagship Linnaean ranks used by default.
.DV_RANKS <- c("kingdom", "phylum", "class", "order",
               "family", "genus", "species")

# d3 category-20 palette (matches the sGSL dashboard look).
.DV_D3 <- c("#1f77b4", "#aec7e8", "#ff7f0e", "#ffbb78", "#2ca02c", "#98df8a",
            "#d62728", "#ff9896", "#9467bd", "#c5b0d5", "#8c564b", "#c49c94",
            "#e377c2", "#f7b6d2", "#7f7f7f", "#c7c7c7", "#bcbd22", "#dbdb8d",
            "#17becf", "#9edae5")

# Silence R CMD check "no visible binding" NOTEs for column names used inside
# dplyr data-masking verbs (dv_build_tree(), dv_digestion_diagnostic()).
utils::globalVariables(c("value_item", "occ", "w", "n_records", "weight"))
