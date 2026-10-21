#' Derive a period covariate from year
#'
#' Cuts whole years into periods. The first period includes its lower break;
#' every later period starts the year after the previous break, so with
#' `breaks = c(2003, 2007, 2020)` the periods are 2003-2007 and 2008-2020, and
#' each label names the years the period actually contains.
#'
#' @param year Numeric vector of years.
#' @param breaks Cut points (as in [base::cut()]), e.g. `c(2003, 2007, 2020)`.
#' @param labels Optional labels; the default builds "first-last" labels from
#'   the years each period contains.
#' @return A factor of periods. Years outside the breaks become `NA`.
#' @examples
#' dv_add_period(c(2004, 2006, 2010, 2018), breaks = c(2003, 2007, 2020))
#' @export
dv_add_period <- function(year, breaks, labels = NULL) {
  if (is.null(labels)) {
    lo <- utils::head(breaks, -1) + 1; lo[1] <- breaks[1]
    labels <- paste0(lo, "-", utils::tail(breaks, -1))
  }
  cut(year, breaks = breaks, labels = labels, include.lowest = TRUE)
}

#' Build per-group length bins
#'
#' Cuts a length vector into bins. Use different `breaks` per predator to merge
#' or split bins where the data warrant it (e.g. `c(0, 20, 30, 40)`). Labels use
#' interval notation that follows `right`: `[a, b)` for left-closed bins (the
#' default) and `(a, b]` for right-closed bins.
#'
#' Lengths outside the breaks become `NA`. A covariate `NA` is not a taxonomic
#' `NA`: the dashboard ([dv_build_html()]) omits `NA` strata, while the Shiny
#' app ([run_dietview()]) shows them as an "NA" panel.
#'
#' @param length Numeric length vector.
#' @param breaks Break edges (ascending).
#' @param right Passed to [base::cut()]; default `FALSE` gives left-closed bins.
#' @param labels Optional labels, one per bin; the default builds interval
#'   labels from `breaks`.
#' @return A factor of length bins.
#' @examples
#' dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60))
#' dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60), right = TRUE)
#' @export
dv_size_bins <- function(length, breaks, right = FALSE, labels = NULL) {
  if (is.null(labels)) {
    lo <- utils::head(breaks, -1); hi <- utils::tail(breaks, -1)
    labels <- if (isTRUE(right)) paste0("(", lo, ", ", hi, "]") else paste0("[", lo, ", ", hi, ")")
  }
  cut(length, breaks = breaks, labels = labels, right = right)
}
