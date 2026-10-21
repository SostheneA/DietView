# Internal helpers -------------------------------------------------------------

.dv_titlecase <- function(x) {
  gsub("(^|[[:space:]])([[:alpha:]])", "\\1\\U\\2", x, perl = TRUE)
}

.dv_slugify <- function(x) tolower(gsub("[^A-Za-z0-9]+", "_", x))

# Replace NA / "" by the explicit "NA" category (character).
.dv_fill_na <- function(x) {
  v <- as.character(x)
  v[is.na(v) | v == ""] <- "NA"
  v
}

.dv_empty_tree <- function() {
  out <- data.frame(
    id = character(0), label = character(0), parent = character(0),
    rank = character(0), value_item = numeric(0), value_occ = numeric(0), value_w = numeric(0),
    pct_occ = numeric(0), pct_w = numeric(0), stringsAsFactors = FALSE
  )
  class(out) <- c("dietview_tree", "data.frame")
  out
}

.dv_pct_fmt <- function(x) {
  ifelse(is.na(x), "n/a", paste0(formatC(x, format = "f", digits = 1), "%"))
}

#' Build a color dictionary for taxon labels
#'
#' Every distinct taxon label gets a color, and the same label gets the same
#' color in every panel built from one dictionary. The palette cycles after 20
#' colors, so in a large survey several taxa share a color; see
#' [dv_palette_tree()] for colors that follow the hierarchy. The unidentified
#' (`"NA"`) category is always white; the sunburst draws a gray outline around
#' every wedge so white wedges stay visible.
#'
#' @param labels Character vector of taxon labels (any rank).
#' @param palette Colors to cycle through. Defaults to a d3 category-20 set.
#' @return A named character vector mapping label -> hex color.
#' @examples
#' dv_palette(c("Teleostei", "Malacostraca", "Polychaeta", "NA"))
#' @export
dv_palette <- function(labels, palette = .DV_D3) {
  labels <- unique(as.character(labels))
  normal <- labels[labels != "NA" & !is.na(labels)]
  cols <- stats::setNames(rep(palette, length.out = length(normal)), normal)
  cols["NA"] <- "#FFFFFF"
  cols
}

#' Colors that follow the taxonomic hierarchy
#'
#' One hue per node at `base_rank` (for example one per phylum), lighter tints
#' of that hue for its descendants, unidentified nodes white. Colors are keyed
#' by node `id`, so a taxon keeps its color in every panel built from trees of
#' the same ranks; pass the result as `colors` to [dv_sunburst()]. Nodes above
#' `base_rank`, and nodes below an unidentified `base_rank` node, are gray.
#'
#' @param tree A `dietview_tree` from [dv_build_tree()] or [dv_tree()]. To keep
#'   colors stable across strata, build the palette from the pooled tree.
#' @param base_rank Position (1 = coarsest) of the rank that gets one hue per
#'   node. Default 2 (phylum with the default ranks).
#' @param palette Base hues to cycle through. Defaults to the ten darker colors
#'   of the d3 category-20 set.
#' @return A named character vector mapping node id -> hex color.
#' @examples
#' csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
#' lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
#' dat <- read.csv(csv, na.strings = c("NA", ""))
#' lineage <- read.csv(lin, na.strings = c("NA", ""))
#' spec <- dv_spec(predator = "predator_species_common_name",
#'                 stomach = "stomach_id", prey_id = "aphia_id",
#'                 prey_name = "verified_name", weight = "prey_weight")
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
#'                    verbose = FALSE)
#' tree <- dv_tree(prep)
#' cols <- dv_palette_tree(tree)
#' head(cols)
#' p <- dv_sunburst(tree, mode = "occurrence", colors = cols)
#' @export
dv_palette_tree <- function(tree, base_rank = 2L, palette = .DV_D3[c(TRUE, FALSE)]) {
  ranks <- unique(tree$rank)
  depth <- match(tree$rank, ranks)
  base  <- tree$id[depth == base_rank & tree$label != "NA"]
  base_col <- stats::setNames(rep(palette, length.out = length(base)), base)
  anc <- vapply(strsplit(tree$id, "|", fixed = TRUE), function(p)
    if (length(p) >= base_rank) paste(p[seq_len(base_rank)], collapse = "|")
    else NA_character_, character(1))
  col <- unname(base_col[anc]); col[is.na(col)] <- "#BDBDBD"
  # tint toward white: 15% per rank below base_rank, at most 75%
  f   <- pmin(0.15 * pmax(depth - base_rank, 0), 0.75)
  m   <- grDevices::col2rgb(col)
  out <- grDevices::rgb(t(m + (255 - m) * rep(f, each = 3)), maxColorValue = 255)
  out[tree$label == "NA"] <- "#FFFFFF"
  stats::setNames(out, tree$id)
}
