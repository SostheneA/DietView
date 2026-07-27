#' Derive a period covariate from year
#'
#' @param year Numeric vector of years.
#' @param breaks Cut points (as in [base::cut()]), e.g. `c(2003, 2007, 2020)`.
#' @param labels Optional labels; default builds "a-b" style labels.
#' @return A factor of periods.
#' @examples
#' dv_add_period(c(2004, 2006, 2010, 2018), breaks = c(2003, 2007, 2020))
#' @export
dv_add_period <- function(year, breaks, labels = NULL) {
  if (is.null(labels)) {
    labels <- paste0(utils::head(breaks, -1), "-", utils::tail(breaks, -1))
  }
  cut(year, breaks = breaks, labels = labels, include.lowest = TRUE)
}

#' Build per-group length bins
#'
#' Cuts a length vector into bins. Use different `breaks` per predator to merge
#' or split bins where the data warrant it (e.g. `c(0, 20, 30, 40)`). Labels are
#' auto-built as "[a-b[".
#'
#' @param length Numeric length vector.
#' @param breaks Break edges (ascending). Rows outside the range become `NA`.
#' @param right Passed to [base::cut()]; default `FALSE` gives left-closed bins.
#' @return A factor of length bins.
#' @examples
#' dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60))
#' @export
dv_size_bins <- function(length, breaks, right = FALSE) {
  labs <- paste0("[", utils::head(breaks, -1), "-", utils::tail(breaks, -1), "[")
  cut(length, breaks = breaks, labels = labs, right = right)
}
