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
    rank = character(0), value_occ = numeric(0), value_w = numeric(0),
    pct_occ = numeric(0), pct_w = numeric(0), stringsAsFactors = FALSE
  )
  class(out) <- c("dietview_tree", "data.frame")
  out
}

.dv_pct_fmt <- function(x) {
  ifelse(is.na(x), "n/a", paste0(formatC(x, format = "f", digits = 1), "%"))
}

#' Build a colour dictionary for taxon labels
#'
#' Every distinct taxon label gets a stable colour; the explicit "NA" category
#' is always white so identification gaps read as blanks in the sunburst.
#'
#' @param labels Character vector of taxon labels (any rank).
#' @param palette Colours to cycle through. Defaults to a d3 category-20 set.
#' @return A named character vector mapping label -> hex colour.
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
