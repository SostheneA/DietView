#' DietView: interactive, hierarchical visualization of predator stomach-content data
#'
#' DietView takes a long table of stomach-content records (one row per prey
#' record), attaches a taxonomic lineage (from WoRMS, or from a lineage table
#' you supply), and shows the whole diet as an interactive multi-rank sunburst.
#' Every record reaches every rank: a record identified only to a coarse rank is
#' kept as an explicit unidentified category below that rank, so each ring
#' accounts for all the material examined and a parent equals the sum of its
#' children. Diet is summarized as shares of prey records (or numbers) and of
#' weight at every rank, alongside the classical frequency of occurrence. Any
#' declared covariate (period, year, size class, length bins, region, ...) can
#' stratify the views, and [dv_digestion_diagnostic()] describes how
#' identification depth changes with digestion state.
#'
#' Main entry points: [dv_spec()], [dv_prepare()], [dv_tree()],
#' [dv_build_tree()], [dv_sunburst()], [dv_digestion_diagnostic()],
#' [dv_build_html()], [run_dietview()].
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
