#' Declare how your columns map to DietView's roles
#'
#' DietView never hard-codes column names. You describe your long table once
#' with `dv_spec()`, then pass the spec to every other function. One row of the
#' table must be one prey record in a stomach.
#'
#' @param predator   Column with the predator name/species.
#' @param stomach    Column with the stomach identifier (unit of occurrence).
#'   It must be unique across the whole table, not only within a predator.
#' @param prey_name  Column with the prey latin name (used if `prey_id` is missing).
#' @param prey_id    Column with the WoRMS AphiaID of the prey (preferred key).
#' @param weight     Column with prey weight (for the weight currency). Optional.
#' @param count      Column with the number of prey individuals. Optional. It is
#'   used only when an output is asked for the numbers currency
#'   (`currency = "numbers"` in [dv_tree()], [dv_build_html()] and
#'   [run_dietview()]); otherwise each record counts once.
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

#' Check a long diet table against a spec before any work is done
#'
#' Stops on problems DietView cannot work around (a declared column is missing,
#' there is no prey key, a weight is negative) and warns about the ones that
#' change what the figures mean (prey keys that are not AphiaIDs, records with no
#' prey key, weights that are not numbers, stomach IDs shared between predators).
#' It then prints a one-line description of the sample. It reports; it does not
#' repair.
#'
#' A missing weight or digestion column is not an error: it only disables the
#' weight views or the digestion diagnostic, and is reported as a message.
#'
#' @param data A data.frame, one row per prey record.
#' @param spec A `dietview_spec` from [dv_spec()].
#' @param strict_covariates If `TRUE` (default) a declared covariate missing from
#'   `data` is an error; if `FALSE` it is dropped from the spec with a warning.
#' @param quiet Suppress the summary and the informational messages (warnings
#'   and errors are never suppressed).
#' @return `data`, invisibly, with two attributes: `dv_spec` (the spec, minus any
#'   dropped covariates) and `dv_report` (a list of counts).
#' @export
dv_validate <- function(data, spec, strict_covariates = TRUE, quiet = FALSE) {
  stopifnot(inherits(spec, "dietview_spec"), is.data.frame(data))
  cols <- names(data); n <- nrow(data)

  miss_req <- setdiff(c(spec$predator, spec$stomach), cols)
  if (length(miss_req))
    stop("Missing required column(s): ", paste(miss_req, collapse = ", "), call. = FALSE)
  if (!any(c(spec$prey_id, spec$prey_name) %in% cols))
    stop("Neither the prey_id nor the prey_name column is in the data.", call. = FALSE)

  cov_miss <- setdiff(spec$covariates, cols)
  if (length(cov_miss)) {
    msg <- paste("Declared covariate(s) absent from the data:", paste(cov_miss, collapse = ", "))
    if (isTRUE(strict_covariates)) stop(msg, call. = FALSE)
    warning(msg, "; they are dropped from the spec.", call. = FALSE)
    spec$covariates <- setdiff(spec$covariates, cov_miss)
  }

  # prey keys
  has_key <- rep(FALSE, n)
  if (!is.null(spec$prey_id) && spec$prey_id %in% cols) {
    raw <- data[[spec$prey_id]]
    id  <- suppressWarnings(as.numeric(as.character(raw)))
    bad <- !is.na(raw) & as.character(raw) != "" &
           (is.na(id) | id <= 0 | id != round(id))
    if (any(bad)) warning(sum(bad), " prey_id value(s) are not positive whole ",
                          "numbers (AphiaIDs).", call. = FALSE)
    has_key <- has_key | (!is.na(id) & !bad)
  }
  if (!is.null(spec$prey_name) && spec$prey_name %in% cols) {
    nm <- trimws(as.character(data[[spec$prey_name]]))
    has_key <- has_key | (!is.na(nm) & nzchar(nm))
  }
  if (any(!has_key)) warning(sum(!has_key), " record(s) have no usable prey key ",
                             "and cannot be placed in any taxon.", call. = FALSE)

  # weight
  n_w_missing <- NA_integer_
  if (!is.null(spec$weight) && spec$weight %in% cols) {
    raw  <- data[[spec$weight]]
    w    <- suppressWarnings(as.numeric(as.character(raw)))
    junk <- !is.na(raw) & trimws(as.character(raw)) != "" & is.na(w)
    if (any(junk)) warning(sum(junk), " weight value(s) are not numbers; they will ",
                           "count as 0.", call. = FALSE)
    if (any(w < 0, na.rm = TRUE))
      stop(sum(w < 0, na.rm = TRUE), " negative weight value(s).", call. = FALSE)
    n_w_missing <- sum(is.na(w))
  } else if (!quiet) {
    message("No weight column: weight-based views (%W) will be empty.")
  }

  # digestion
  if (!is.null(spec$digestion) && spec$digestion %in% cols) {
    k <- length(unique(stats::na.omit(data[[spec$digestion]])))
    if (k > 10) warning("The digestion column has ", k, " distinct values; a ",
                        "scoring scale usually has fewer than 10.", call. = FALSE)
  } else if (!quiet) {
    message("No digestion column: the digestion diagnostic is disabled.")
  }

  # stomach IDs must be unique across predators
  sp <- unique(data.frame(s = as.character(data[[spec$stomach]]),
                          p = as.character(data[[spec$predator]]),
                          stringsAsFactors = FALSE))
  shared <- unique(sp$s[duplicated(sp$s)])
  if (length(shared))
    warning(length(shared), " stomach id(s) occur under more than one predator ",
            "(e.g. ", paste(utils::head(shared, 3), collapse = ", "), "). Stomach ",
            "counts would merge them; build a unique id first.", call. = FALSE)

  st <- table(as.character(data[[spec$stomach]]))
  report <- list(n_records = n, n_stomachs = length(st),
                 n_predators = length(unique(data[[spec$predator]])),
                 n_single_record_stomachs = sum(st == 1),
                 n_missing_weight = n_w_missing, n_no_prey_key = sum(!has_key))
  if (!quiet)
    message(sprintf("%d records from %d stomachs of %d predator(s); %d stomach(s) hold a single record; %s record(s) lack a weight.",
                    report$n_records, report$n_stomachs, report$n_predators,
                    report$n_single_record_stomachs,
                    if (is.na(n_w_missing)) "n/a" else n_w_missing))
  attr(data, "dv_spec")   <- spec
  attr(data, "dv_report") <- report
  invisible(data)
}
