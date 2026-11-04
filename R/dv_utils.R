# Internal helpers -------------------------------------------------------------

.dv_titlecase <- function(x) {
  gsub("(^|[[:space:]])([[:alpha:]])", "\\1\\U\\2", x, perl = TRUE)
}

.dv_slugify <- function(x) tolower(gsub("[^A-Za-z0-9]+", "_", x))

# Null default (base R has it only from 4.4.0).
`%||%` <- function(a, b) if (is.null(a)) b else a

# Replace NA / "" by the explicit "NA" category (character).
.dv_fill_na <- function(x) {
  v <- as.character(x)
  v[is.na(v) | v == ""] <- "NA"
  v
}

# Lineage gaps: a rank WoRMS does not define for a group (e.g. many polychaete
# families have no order) above a rank that is identified. They are labelled
# "<nearest named ancestor> (no <rank>)" and drawn gray, not white.
.DV_GAP_COLOR <- "#D9D9D9"

.dv_gap_label <- function(ancestor, rank) {
  rank <- tolower(rank)
  ifelse(is.na(ancestor) | ancestor == "",
         paste0("(no ", rank, ")"),
         paste0(ancestor, " (no ", rank, ")"))
}

.dv_is_gap <- function(x) {
  x <- as.character(x)
  !is.na(x) & grepl("^(.+ )?\\(no [a-z_]+\\)$", x)
}

# Internal: one rank given as its column name ("class") or display label
# ("Class"), case-insensitive and trimmed; returns the matching element of
# `ranks`.
.dv_match_rank <- function(rank, ranks, arg = "rank") {
  valid <- paste(ranks, collapse = ", ")
  if (length(rank) != 1L || is.na(rank))
    stop("`", arg, "` must be a single rank, one of: ", valid, ".", call. = FALSE)
  hit <- match(tolower(trimws(as.character(rank))), tolower(trimws(ranks)))
  if (is.na(hit))
    stop("Unknown `", arg, "` \"", rank, "\". Use one of: ", valid, ".", call. = FALSE)
  ranks[hit]
}

# Numeric value of a column. Factors go through their labels, not their level
# codes; values that are not numbers become NA.
.dv_as_num <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  suppressWarnings(as.numeric(x))
}

# A taxon label as one component of a node id: "|" is the rank separator, so
# it is replaced by a broken bar.
.dv_id_part <- function(x) gsub("|", "\u00a6", as.character(x), fixed = TRUE)

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
#' every wedge so white wedges stay visible. Lineage gaps (labels such as
#' `"Polychaeta (no order)"`, see the `gaps` argument of [dv_prepare()]) are
#' light gray.
#'
#' @param labels Character vector of taxon labels (any rank).
#' @param palette Colors to cycle through. Defaults to a d3 category-20 set.
#' @return A named character vector mapping label -> hex color.
#' @examples
#' dv_palette(c("Teleostei", "Malacostraca", "Polychaeta", "NA"))
#' @export
dv_palette <- function(labels, palette = .DV_D3) {
  labels <- unique(as.character(labels))
  gap    <- labels[.dv_is_gap(labels)]
  normal <- labels[labels != "NA" & !is.na(labels) & !.dv_is_gap(labels)]
  cols <- stats::setNames(rep(palette, length.out = length(normal)), normal)
  cols[gap] <- .DV_GAP_COLOR
  cols["NA"] <- "#FFFFFF"
  cols
}

#' Colors that follow the taxonomic hierarchy
#'
#' One hue per node at `base_rank` (for example one per phylum), lighter tints
#' of that hue for its descendants, unidentified nodes white. Colors are keyed
#' by node `id`, so a taxon keeps its color in every panel built from trees of
#' the same ranks; pass the result as `colors` to [dv_sunburst()]. Nodes above
#' `base_rank`, and nodes below an unidentified `base_rank` node, are gray. A
#' lineage gap node (e.g. `"Polychaeta (no order)"`) is light gray itself, while
#' its descendants keep the tint of their `base_rank` ancestor.
#'
#' @param tree A `dietview_tree` from [dv_build_tree()] or [dv_tree()]. To keep
#'   colors stable across strata, build the palette from the pooled tree.
#' @param base_rank Position (1 = coarsest) of the rank that gets one hue per
#'   node. Default 2 (phylum with the default ranks).
#' @param palette Base hues to cycle through. Defaults to the ten darker colors
#'   of the d3 category-20 set.
#' @return A named character vector mapping node id -> hex color.
#' @examples
#' # the standard set-up: public ICES data, non-food items and nematodes dropped
#' phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
#' dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
#' spec <- dv_spec(
#'   predator       = "predator_common",
#'   predator_latin = "predator_latin",
#'   stomach        = "stomach_id",
#'   prey_id        = "prey_aphia_id",
#'   prey_name      = "prey_name",
#'   weight         = "prey_weight_g",
#'   count          = "prey_count",
#'   digestion      = "digestion_label",
#'   covariates     = c("region", "year", "quarter")
#' )
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
#'                    verbose = FALSE)
#' tree <- dv_tree(prep)
#' cols <- dv_palette_tree(tree)
#' head(cols)
#' p <- dv_sunburst(tree, mode = "occurrence", colors = cols)
#' @export
dv_palette_tree <- function(tree, base_rank = 2L, palette = .DV_D3[c(TRUE, FALSE)]) {
  # depth from the id itself, so the row order of `tree` does not matter
  parts <- strsplit(tree$id, "|", fixed = TRUE)
  depth <- lengths(parts)
  # hues follow the sorted ids, not the row order
  base  <- sort(tree$id[depth == base_rank & tree$label != "NA"], method = "radix")
  base_col <- stats::setNames(rep(palette, length.out = length(base)), base)
  anc <- vapply(parts, function(p)
    if (length(p) >= base_rank) paste(p[seq_len(base_rank)], collapse = "|")
    else NA_character_, character(1))
  col <- unname(base_col[anc]); col[is.na(col)] <- "#BDBDBD"
  # tint toward white: 15% per rank below base_rank, at most 75%
  f   <- pmin(0.15 * pmax(depth - base_rank, 0), 0.75)
  m   <- grDevices::col2rgb(col)
  out <- grDevices::rgb(t(m + (255 - m) * rep(f, each = 3)), maxColorValue = 255)
  out[.dv_is_gap(tree$label)] <- .DV_GAP_COLOR
  out[tree$label == "NA"] <- "#FFFFFF"
  stats::setNames(out, tree$id)
}

# Internal: the name of the sampling unit (spec$unit_label), singular (n = 1)
# or plural (n = 2), optionally capitalized. Old specs without the field read
# "stomach".
.dv_unit <- function(spec, n = 2L, cap = FALSE) {
  u <- spec$unit_label %||% "stomach"
  out <- if (n == 1L) u[1] else if (length(u) >= 2L) u[2] else paste0(u[1], "s")
  if (cap) paste0(toupper(substr(out, 1, 1)), substr(out, 2, nchar(out))) else out
}
