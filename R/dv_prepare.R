#' Prepare a diet table for DietView (validate + add taxa)
#'
#' Validates the long table with [dv_validate()] and attaches the taxonomic
#' lineage for the declared ranks. The taxonomy can come from:
#' \itemize{
#'   \item `"columns"` - the rank columns are already in `data`;
#'   \item `"worms"`   - fetch the lineage from WoRMS by AphiaID/name;
#'   \item `"table"`   - join a lineage table you supply via `lineage`;
#'   \item `"auto"`    - use columns if present, else `lineage` if given, else WoRMS.
#' }
#' Ranks that cannot be resolved are kept as `NA` and later shown as an explicit
#' unidentified category below the deepest identified rank -- never dropped.
#'
#' With `taxonomy = "worms"`, each record is keyed by its AphiaID when it has
#' one and by its own prey name otherwise, so records without an AphiaID never
#' share a lineage by accident. Records with neither key stay fully
#' unidentified, with a warning.
#'
#' With `taxonomy = "table"`, the lineage table must hold each key once (a
#' duplicated key is an error), and prey keys absent from the table are reported
#' with a warning before their records are treated as fully unidentified.
#'
#' @param data A data.frame (the long diet table).
#' @param spec A `dietview_spec` from [dv_spec()].
#' @param taxonomy One of "auto", "columns", "worms", "table".
#' @param lineage For `taxonomy = "table"`: a data.frame with a key column
#'   (`prey_id` or `prey_name`, matching your spec) plus one column per rank.
#' @param fuzzy For `taxonomy = "worms"`: when the exact name fails, try WoRMS
#'   TAXAMATCH fuzzy matching (default `TRUE`). Fuzzy hits are flagged, never
#'   silent - review them with [dv_taxonomy_report()].
#' @param cache_dir Cache directory for the WoRMS path. `NULL` disables caching.
#' @param cache_max_age For the WoRMS path: cached lookups older than this many
#'   days are fetched again (default 180). See [dv_taxonomy_worms()].
#' @param strict_covariates Passed to [dv_validate()]: if `TRUE` (default) a
#'   declared covariate missing from `data` is an error; if `FALSE` it is dropped
#'   from the returned spec with a warning.
#' @param verbose Print progress and the validation summary.
#' @return An object of class `dietview_prep`: a list with `data`, `spec` (minus
#'   any dropped covariates), `ranks`, `taxonomy_source` (the taxonomy path
#'   actually used) and `taxonomy_log`. When `taxonomy = "worms"`,
#'   `taxonomy_log` is the per-prey provenance table, with the attributes
#'   `retrieved` (time of the run) and `worrms_version`; otherwise it is `NULL`.
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
#' prep
#' \dontrun{
#' # online: resolve prey against WoRMS (needs 'worrms' + internet)
#' prep_worms <- dv_prepare(dat, spec, taxonomy = "worms")
#' }
#' @export
dv_prepare <- function(data, spec,
                       taxonomy = c("auto", "columns", "worms", "table"),
                       lineage = NULL,
                       fuzzy = TRUE,
                       cache_dir = tools::R_user_dir("DietView", "cache"),
                       cache_max_age = 180,
                       strict_covariates = TRUE,
                       verbose = TRUE) {
  taxonomy <- match.arg(taxonomy)
  checked <- dv_validate(data, spec, strict_covariates = strict_covariates,
                         quiet = !verbose)
  spec <- attr(checked, "dv_spec")
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
    if (!key %in% names(data))
      stop("The lineage key column `", key, "` is not in `data`.", call. = FALSE)

    lk <- trimws(as.character(lineage[[key]]))
    dk <- trimws(as.character(data[[key]]))
    dup <- unique(lk[duplicated(lk) & !is.na(lk)])
    if (length(dup))
      stop("`lineage` has ", length(dup), " duplicated key(s), e.g. ",
           paste(utils::head(dup, 3), collapse = ", "), call. = FALSE)
    # incomparables = NA: a record without a key never inherits the lineage of
    # a lineage row without a key
    idx <- match(dk, lk, incomparables = NA)
    absent <- unique(dk[is.na(idx) & !is.na(dk)])
    if (length(absent))
      warning(length(absent), " prey key(s) are absent from `lineage` (e.g. ",
              paste(utils::head(absent, 3), collapse = ", "),
              "); their records are treated as fully unidentified.", call. = FALSE)
    for (r in ranks) data[[r]] <- lineage[[r]][idx]

  } else if (taxonomy == "worms") {
    n <- nrow(data)
    rec_id <- if (!is.null(spec$prey_id) && spec$prey_id %in% names(data))
      suppressWarnings(as.integer(as.character(data[[spec$prey_id]]))) else rep(NA_integer_, n)
    rec_nm <- if (!is.null(spec$prey_name) && spec$prey_name %in% names(data))
      trimws(as.character(data[[spec$prey_name]])) else rep(NA_character_, n)

    # one key per record: the AphiaID when there is one, otherwise the name
    rec_key <- ifelse(!is.na(rec_id), paste0("id:", rec_id),
               ifelse(!is.na(rec_nm) & nzchar(rec_nm),
                      paste0("nm:", tolower(rec_nm)), NA_character_))
    first <- which(!is.na(rec_key) & !duplicated(rec_key))
    keys  <- data.frame(key = rec_key[first], prey_id = rec_id[first],
                        prey_name = rec_nm[first], stringsAsFactors = FALSE)

    keys <- dv_taxonomy_worms(keys, ranks = ranks, cache_dir = cache_dir,
                              fuzzy = fuzzy, cache_max_age = cache_max_age,
                              verbose = verbose)
    idx <- match(rec_key, keys$key)              # records without a key stay NA
    for (r in ranks) data[[r]] <- keys[[r]][idx]

    # provenance log: how each prey was matched, and how many records it affects
    key_f <- factor(rec_key, levels = keys$key)  # levels are unique by construction
    names_seen <- tapply(rec_nm, key_f, function(z)
      paste(sort(unique(stats::na.omit(z))), collapse = " | "))
    tax_log <- data.frame(
      prey_name    = keys$prey_name,
      prey_id      = keys$prey_id,
      names_seen   = as.character(names_seen),   # >1 name under one AphiaID: check it
      match_type   = keys$match_type,
      name_check   = keys$name_check,
      matched_name = keys$matched_name,
      aphia_used   = keys$aphia_used,
      n_candidates = keys$n_candidates,
      homonym      = keys$homonym,
      lineage_ok   = keys$lineage_ok,
      retrieved    = keys$retrieved,
      n_records    = as.integer(table(key_f)),
      stringsAsFactors = FALSE
    )
    tax_log <- cbind(tax_log, keys[, ranks, drop = FALSE])
    attr(tax_log, "retrieved")      <- format(Sys.time(), "%Y-%m-%d %H:%M %Z")
    attr(tax_log, "worrms_version") <- as.character(utils::packageVersion("worrms"))

    n_nokey <- sum(is.na(rec_key))
    if (n_nokey) warning(n_nokey, " record(s) have neither an AphiaID nor a prey ",
                         "name; they are kept as fully unidentified.", call. = FALSE)
  }

  # normalise the string "NA" (from CSVs) to real NA in rank columns
  for (r in ranks) {
    v <- as.character(data[[r]]); v[v == "NA" | v == ""] <- NA
    data[[r]] <- v
  }

  out <- list(data = data, spec = spec, ranks = ranks,
              taxonomy_source = taxonomy, taxonomy_log = tax_log)
  class(out) <- "dietview_prep"
  out
}

# Match types written by dv_taxonomy_worms(), in display order.
.DV_MATCH_TYPES <- c("id", "id_synonym", "id_unchecked", "exact", "fuzzy",
                     "unresolved")

#' @export
print.dietview_prep <- function(x, ...) {
  cat("<dietview_prep>\n")
  cat("  records   :", nrow(x$data), "\n")
  cat("  stomachs  :", length(unique(x$data[[x$spec$stomach]])), "\n")
  cat("  predators :", length(unique(x$data[[x$spec$predator]])), "\n")
  cat("  ranks     :", paste(x$ranks, collapse = " > "), "\n")
  cat("  covariates:", paste(x$spec$covariates, collapse = ", "), "\n")
  if (!is.null(x$taxonomy_source))
    cat("  source    :", x$taxonomy_source, "\n")
  if (!is.null(x$taxonomy_log)) {
    tb <- table(factor(x$taxonomy_log$match_type, levels = .DV_MATCH_TYPES))
    cat("  taxonomy  : ", paste(sprintf("%s=%d", names(tb), as.integer(tb)),
                                collapse = ", "), "\n", sep = "")
    if (nrow(.dv_review_rows(x$taxonomy_log)) > 0)
      cat("              review: dv_taxonomy_report(prep)\n")
  }
  invisible(x)
}
