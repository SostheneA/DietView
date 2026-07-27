#' Declare how your columns map to DietView's roles
#'
#' DietView never hard-codes column names. You describe your long table once
#' with `dv_spec()`, then pass the spec to every other function. One row of the
#' table must be one prey record in a stomach.
#'
#' @param predator   Column with the predator name/species.
#' @param stomach    Column with the stomach identifier (unit of occurrence).
#' @param prey_name  Column with the prey latin name (used if `prey_id` is missing).
#' @param prey_id    Column with the WoRMS AphiaID of the prey (preferred key).
#' @param weight     Column with prey weight (for the weight currency). Optional.
#' @param count      Column with the number of prey individuals. Optional; if
#'   absent, one occurrence = one record.
#' @param digestion  Column with the digestion level (enables digestion
#'   diagnostics). Optional.
#' @param covariates Character vector of covariate columns to allow as strata
#'   (e.g. `c("period", "year", "size_class")`).
#' @param ranks      Taxonomic ranks to display, coarse to fine. Defaults to the
#'   seven flagship ranks kingdom..species. If your table already carries these
#'   columns, keep the default; otherwise they are filled by [dv_prepare()].
#' @param predator_latin Optional column with the predator Latin name (used to
#'   auto-fetch identification photos).
#'
#' @return An object of class `dietview_spec`.
#' @examples
#' spec <- dv_spec(
#'   predator = "predator_species_common_name",
#'   stomach  = "stomach_id",
#'   prey_id  = "aphia_id",
#'   prey_name = "verified_name",
#'   weight   = "prey_weight",
#'   covariates = c("period", "size_class")
#' )
#' spec$ranks
#' @export
dv_spec <- function(predator, stomach,
                    prey_name = NULL, prey_id = NULL,
                    weight = NULL, count = NULL, digestion = NULL,
                    covariates = character(0),
                    ranks = c("kingdom", "phylum", "class", "order",
                              "family", "genus", "species"),
                    predator_latin = NULL) {
  if (is.null(prey_name) && is.null(prey_id)) {
    stop("Provide at least one of `prey_name` or `prey_id`.", call. = FALSE)
  }
  structure(
    list(predator = predator, stomach = stomach,
         prey_name = prey_name, prey_id = prey_id,
         weight = weight, count = count, digestion = digestion,
         covariates = covariates, ranks = ranks,
         predator_latin = predator_latin),
    class = "dietview_spec"
  )
}

#' Validate a long table against a spec
#'
#' Checks that every declared column exists and reports missing weight/digestion
#' so you know which currencies and diagnostics will be available.
#'
#' @param data A data.frame (the long diet table).
#' @param spec A `dietview_spec` from [dv_spec()].
#' @param strict_covariates If TRUE (default), missing covariates are hard
#'   errors. If FALSE, they are dropped from `spec$covariates` with a warning.
#' @return `data` invisibly (stops on hard errors, warns on soft gaps).
#' @export
dv_validate <- function(data, spec, strict_covariates = TRUE) {
  stopifnot(inherits(spec, "dietview_spec"), is.data.frame(data))

  required <- c(spec$predator, spec$stomach)
  keys     <- c(spec$prey_id, spec$prey_name)
  cols     <- names(data)

  miss_req <- setdiff(stats::na.omit(required), cols)
  if (length(miss_req)) {
    stop("Missing required columns: ",
         paste(miss_req, collapse = ", "), call. = FALSE)
  }
  if (!any(keys %in% cols)) {
    stop("Neither prey_id nor prey_name column is present.", call. = FALSE)
  }

  cov_miss <- setdiff(spec$covariates, cols)
  if (length(cov_miss)) {
    msg <- paste("Declared covariates absent from data:",
                 paste(cov_miss, collapse = ", "))
    if (isTRUE(strict_covariates)) {
      stop(msg, call. = FALSE)
    } else {
      warning(msg, call. = FALSE)
      # drop missing covariates from the spec object
      spec$covariates <- setdiff(spec$covariates, cov_miss)
    }
  }

  if (is.null(spec$weight) || !spec$weight %in% cols) {
    warning("No weight column: weight-based views (%W) will be empty.",
            call. = FALSE)
  }
  if (is.null(spec$digestion) || !spec$digestion %in% cols) {
    message("No digestion column: digestion diagnostics disabled.")
  }

  invisible(data)
}
