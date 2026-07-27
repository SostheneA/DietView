#' Prepare a diet table for DietView (validate + add taxa)
#'
#' Validates the long table and attaches the taxonomic lineage for the declared
#' ranks. The taxonomy can come from:
#' \itemize{
#'   \item `"columns"` - the rank columns are already in `data`;
#'   \item `"worms"`   - fetch the lineage from WoRMS by AphiaID/name;
#'   \item `"table"`   - join a lineage lookup you supply via `lineage`;
#'   \item `"auto"`    - use columns if present, else `lineage` if given, else WoRMS.
#' }
#' Ranks that cannot be resolved are kept as `NA` and later shown as the explicit
#' "NA" category -- never dropped.
#'
#' @param data A data.frame (the long diet table).
#' @param spec A `dietview_spec` from [dv_spec()].
#' @param taxonomy One of "auto", "columns", "worms", "table".
#' @param lineage For `taxonomy = "table"`: a data.frame with a key column
#'   (`prey_id` or `prey_name`, matching your spec) plus one column per rank.
#' @param fuzzy For `taxonomy = "worms"`: allow fuzzy name matching as a fallback
#'   when the exact name fails (default `TRUE`). Fuzzy hits are flagged, never
#'   silent - review them with [dv_taxonomy_report()].
#' @param cache_dir Cache directory for the WoRMS path.
#' @param verbose Print progress.
#' @return An object of class `dietview_prep`. When `taxonomy = "worms"`, it also
#'   carries `$taxonomy_log`, the per-prey provenance table.
#' @examples
#' csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
#' lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
#' dat <- read.csv(csv, na.strings = c("NA", ""))
#' lineage <- read.csv(lin, na.strings = c("NA", ""))
#' spec <- dv_spec(predator = "predator_species_common_name",
#'                 stomach = "stomach_id",
#'                 prey_id = "aphia_id",
#'                 prey_name = "verified_name",
#'                 weight = "prey_weight")
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
#'                    verbose = FALSE)
#' prep
#' \dontrun{
#' # online: resolve prey against WoRMS (needs 'worrms' + internet)
#' prep <- dv_prepare(dat, spec, taxonomy = "worms")
#' }
#' @export
dv_prepare <- function(data, spec,
                       taxonomy = c("auto", "columns", "worms", "table"),
                       lineage = NULL,
                       fuzzy = TRUE,
                       cache_dir = tools::R_user_dir("DietView", "cache"),
                       verbose = TRUE) {
  taxonomy <- match.arg(taxonomy)
  dv_validate(data, spec)
  data <- as.data.frame(data)
  ranks <- spec$ranks
  tax_log <- NULL

  if (taxonomy == "auto") {
    if (all(ranks %in% names(data))) taxonomy <- "columns"
    else if (!is.null(lineage))      taxonomy <- "table"
    else                             taxonomy <- "worms"
    if (verbose) message("taxonomy = 'auto' -> using '", taxonomy, "'")
  }

  if (taxonomy == "columns") {
    miss <- setdiff(ranks, names(data))
    if (length(miss)) {
      stop("taxonomy = 'columns' but these rank columns are absent: ",
           paste(miss, collapse = ", "),
           ". Use 'worms' or 'table' to add them.", call. = FALSE)
    }

  } else if (taxonomy == "table") {
    if (is.null(lineage)) stop("taxonomy = 'table' needs a `lineage` data.frame.", call. = FALSE)
    lineage <- as.data.frame(lineage)
    key <- if (!is.null(spec$prey_id) && spec$prey_id %in% names(lineage)) spec$prey_id
    else if (!is.null(spec$prey_name) && spec$prey_name %in% names(lineage)) spec$prey_name
    else stop("`lineage` must contain the prey_id or prey_name key column.", call. = FALSE)
    miss <- setdiff(ranks, names(lineage))
    if (length(miss)) stop("`lineage` is missing rank columns: ",
                           paste(miss, collapse = ", "), call. = FALSE)
    idx <- match(as.character(data[[key]]), as.character(lineage[[key]]))
    for (r in ranks) data[[r]] <- lineage[[r]][idx]

  } else if (taxonomy == "worms") {
    id_col <- spec$prey_id; nm_col <- spec$prey_name
    keys <- unique(data.frame(
      prey_id   = if (!is.null(id_col)) data[[id_col]] else NA_integer_,
      prey_name = if (!is.null(nm_col)) data[[nm_col]] else NA_character_,
      stringsAsFactors = FALSE
    ))
    keys <- dv_taxonomy_worms(keys, ranks = ranks, cache_dir = cache_dir,
                              fuzzy = fuzzy, verbose = verbose)
    key_col <- if (!is.null(id_col)) "prey_id" else "prey_name"
    data_key <- if (!is.null(id_col)) data[[id_col]] else data[[nm_col]]
    idx <- match(as.character(data_key), as.character(keys[[key_col]]))
    for (r in ranks) data[[r]] <- keys[[r]][idx]

    # provenance log: how each prey was matched, and how many records it affects
    n_rec <- as.integer(table(factor(as.character(data_key),
                                     levels = as.character(keys[[key_col]]))))
    tax_log <- data.frame(
      prey_name    = keys$prey_name,
      prey_id      = keys$prey_id,
      match_type   = keys$match_type,
      matched_name = keys$matched_name,
      aphia_used   = keys$aphia_used,
      n_records    = n_rec,
      stringsAsFactors = FALSE
    )
    tax_log <- cbind(tax_log, keys[, ranks, drop = FALSE])
  }

  # normalise the string "NA" (from CSVs) to real NA in rank columns
  for (r in ranks) {
    v <- as.character(data[[r]]); v[v == "NA" | v == ""] <- NA
    data[[r]] <- v
  }

  out <- list(data = data, spec = spec, ranks = ranks, taxonomy_log = tax_log)
  class(out) <- "dietview_prep"
  out
}

#' @export
print.dietview_prep <- function(x, ...) {
  cat("<dietview_prep>\n")
  cat("  records   :", nrow(x$data), "\n")
  cat("  predators :", length(unique(x$data[[x$spec$predator]])), "\n")
  cat("  ranks     :", paste(x$ranks, collapse = " > "), "\n")
  cat("  covariates:", paste(x$spec$covariates, collapse = ", "), "\n")
  if (!is.null(x$taxonomy_log)) {
    tb <- table(factor(x$taxonomy_log$match_type,
                       levels = c("id", "exact", "fuzzy", "unresolved")))
    cat("  taxonomy  : ", paste(sprintf("%s=%d", names(tb), as.integer(tb)),
                                collapse = ", "), "\n", sep = "")
    if (tb[["fuzzy"]] > 0 || tb[["unresolved"]] > 0)
      cat("              review: dv_taxonomy_report(prep)\n")
  }
  invisible(x)
}
