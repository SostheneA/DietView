#' Prepare a diet table for DietView (validate + add taxa)
#'
#' Validates the long table with [dv_validate()] and attaches the taxonomic
#' lineage for the declared ranks. The taxonomy can come from:
#' \itemize{
#'   \item `"columns"` - the rank columns are already in `data`;
#'   \item `"worms"`   - fetch the lineage from WoRMS by AphiaID/name (marine
#'     prey; see [dv_taxonomy_worms()]);
#'   \item `"gbif"`    - fetch the lineage from the GBIF Backbone Taxonomy by
#'     GBIF taxon key/name (all kingdoms, terrestrial and freshwater prey; see
#'     [dv_taxonomy_gbif()]);
#'   \item `"table"`   - join a lineage table you supply via `lineage`;
#'   \item `"auto"`    - use columns if present, else `lineage` if given, else WoRMS.
#' }
#' Ranks that cannot be resolved are kept as `NA` and later shown as an explicit
#' unidentified category below the deepest identified rank -- never dropped.
#'
#' With `taxonomy = "worms"` or `"gbif"`, each record is keyed by its AphiaID
#' (or GBIF taxon key) when it has one and by its own prey name otherwise, so records without an AphiaID never
#' share a lineage by accident. Records with neither key stay fully
#' unidentified, with a warning.
#'
#' Some groups have no taxon at a rank in WoRMS: several polychaete families
#' have no order, lancelets have no order and Priapulida have no class. A record
#' identified below such a rank would otherwise sit under an `"NA"` node there
#' and look unidentified. With `gaps = "label"` (the default) that empty rank is
#' filled with `"<nearest named ancestor> (no <rank>)"`, e.g.
#' `"Polychaeta (no order)"` above Opheliidae; the sunburst draws it gray, not
#' white, and its records no longer inflate the unidentified share of that
#' rank. Only ranks with an identified rank below them are filled: a record
#' identified to class and no further keeps `NA` at order, family, genus and
#' species, because it is truly unidentified there. The number of filled cells
#' per rank is stored in the attribute `lineage_gaps`.
#'
#' With `taxonomy = "table"`, the lineage table must hold each key once (a
#' duplicated key is an error), and prey keys absent from the table are reported
#' with a warning before their records are treated as fully unidentified.
#'
#' @param data A data.frame (the long diet table).
#' @param spec A `dietview_spec` from [dv_spec()].
#' @param taxonomy One of "auto", "columns", "worms", "gbif", "table". `"auto"`
#'   never picks `"gbif"`: ask for it explicitly.
#' @param lineage For `taxonomy = "table"`: a data.frame with a key column
#'   (`prey_id` or `prey_name`, matching your spec) plus one column per rank.
#' @param fuzzy For `taxonomy = "worms"` or `"gbif"`: when the exact name fails, try WoRMS
#'   TAXAMATCH fuzzy matching (default `TRUE`). Fuzzy hits are flagged, never
#'   silent - review them with [dv_taxonomy_report()].
#' @param kingdom For `taxonomy = "gbif"`: an optional kingdom hint, e.g.
#'   `"Animalia"`. See [dv_taxonomy_gbif()].
#' @param cache_dir Cache directory for the WoRMS and GBIF paths. `NULL` disables caching.
#' @param cache_max_age For the WoRMS path: cached lookups older than this many
#'   days are fetched again (default 180). See [dv_taxonomy_worms()].
#' @param strict_covariates Passed to [dv_validate()]: if `TRUE` (default) a
#'   declared covariate missing from `data` is an error; if `FALSE` it is dropped
#'   from the returned spec with a warning.
#' @param stomachs Optional data.frame with one row per examined stomach, empty
#'   ones included (e.g. [ices_stomachs]): the stomach column of the spec, plus
#'   optionally the predator and covariate columns and an empty flag (see
#'   `empty_col`). It is stored as `prep$stomachs` and lets [dv_summary()]
#'   report vacuity, [dv_fo_table()] use all examined stomachs as the
#'   denominator, and [dv_matrix()] add rows for empty stomachs. Without it, a
#'   long prey table holds only non-empty stomachs: %FO is over non-empty
#'   stomachs and the matrix has no empty rows. Stomachs of predators absent
#'   from `data` are ignored, so the full sampling frame can be passed with a
#'   subset of the predators. Stomachs whose records were all removed before
#'   `dv_prepare()` (e.g. they held only non-food items or nematodes) are
#'   counted neither as empty nor as examined; to count them as examined but
#'   empty, flag them empty in `stomachs` before calling `dv_prepare()`. Two
#'   checks warn once, with a count and up to three example ids: stomachs that
#'   have prey records but are absent from `stomachs` (counted as examined and
#'   non-empty), and stomachs whose predator in `stomachs` differs from the
#'   predator of their records (the predator of the records is used).
#' @param empty_col Optional column of `stomachs` flagging empty stomachs
#'   (logical, or 0/1). With it, a stomach without records counts as empty only
#'   when flagged; one that is neither flagged nor in `data` has an unknown
#'   status and is left out of every count. Without it, every stomach of
#'   `stomachs` without a record in `data` counts as empty.
#' @param gaps How to show a rank that has no taxon in the lineage between two
#'   identified ranks: `"label"` (default) fills it with
#'   `"<ancestor> (no <rank>)"`, e.g. `"Polychaeta (no order)"`; `"keep"` leaves
#'   it `NA`, so its records sit under the unidentified node of that rank.
#' @param verbose Print progress and the validation summary.
#' @return An object of class `dietview_prep`: a list with `data`, `spec` (minus
#'   any dropped covariates), `ranks`, `taxonomy_source` (the taxonomy path
#'   actually used) and `taxonomy_log`. When `taxonomy = "worms"` or `"gbif"`,
#'   `taxonomy_log` is the per-prey provenance table, with the attributes
#'   `retrieved` (time of the run), `source` (`"WoRMS"` or `"GBIF Backbone"`)
#'   and, for WoRMS, `worrms_version`; otherwise it is `NULL`. Its ID column is
#'   `aphia_used` for WoRMS and `gbif_key` for GBIF.
#'   The attribute `lineage_gaps` is a named integer vector: the number of
#'   records whose rank was filled as a lineage gap, per rank. With `stomachs`,
#'   the list also holds `stomachs`: the examined stomachs, with their stomach,
#'   predator and covariate columns and a logical `empty_flag` column.
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
                       taxonomy = c("auto", "columns", "worms", "gbif", "table"),
                       lineage = NULL,
                       fuzzy = TRUE,
                       kingdom = NULL,
                       cache_dir = tools::R_user_dir("DietView", "cache"),
                       cache_max_age = 180,
                       strict_covariates = TRUE,
                       stomachs = NULL,
                       empty_col = NULL,
                       gaps = c("label", "keep"),
                       verbose = TRUE) {
  taxonomy <- match.arg(taxonomy)
  gaps <- match.arg(gaps)
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

  } else if (taxonomy %in% c("worms", "gbif")) {
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

    keys <- if (taxonomy == "worms")
      dv_taxonomy_worms(keys, ranks = ranks, cache_dir = cache_dir,
                        fuzzy = fuzzy, cache_max_age = cache_max_age,
                        verbose = verbose)
    else
      dv_taxonomy_gbif(keys, ranks = ranks, cache_dir = cache_dir,
                       fuzzy = fuzzy, kingdom = kingdom,
                       cache_max_age = cache_max_age, verbose = verbose)
    id_col <- if (taxonomy == "worms") "aphia_used" else "gbif_key"
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
      used_id      = keys[[id_col]],
      n_candidates = keys$n_candidates,
      homonym      = keys$homonym,
      lineage_ok   = keys$lineage_ok,
      retrieved    = keys$retrieved,
      n_records    = as.integer(table(key_f)),
      stringsAsFactors = FALSE
    )
    names(tax_log)[names(tax_log) == "used_id"] <- id_col
    if (taxonomy == "gbif") {
      tax_log$confidence     <- keys$confidence
      tax_log$low_confidence <- keys$low_confidence
    }
    tax_log <- cbind(tax_log, keys[, ranks, drop = FALSE])
    attr(tax_log, "retrieved") <- format(Sys.time(), "%Y-%m-%d %H:%M %Z")
    attr(tax_log, "source")    <- if (taxonomy == "worms") "WoRMS" else "GBIF Backbone"
    if (taxonomy == "worms")
      attr(tax_log, "worrms_version") <- as.character(utils::packageVersion("worrms"))

    n_nokey <- sum(is.na(rec_key))
    if (n_nokey) warning(n_nokey, " record(s) have neither a prey ID nor a prey ",
                         "name; they are kept as fully unidentified.", call. = FALSE)
  }

  # normalise the string "NA" (from CSVs) to real NA in rank columns
  for (r in ranks) {
    v <- as.character(data[[r]]); v[v == "NA" | v == ""] <- NA
    data[[r]] <- v
  }

  n_gap <- stats::setNames(integer(length(ranks)), ranks)
  if (gaps == "label") {
    data <- .dv_fill_gaps(data, ranks)
    n_gap <- attr(data, "lineage_gaps"); attr(data, "lineage_gaps") <- NULL
    if (verbose && sum(n_gap) > 0) {
      nz <- n_gap[n_gap > 0]
      message("Filled ", sum(n_gap), " lineage gap(s) (rank absent in the taxonomy): ",
              paste0(names(nz), "=", nz, collapse = ", "),
              ". They are shown as '<parent> (no <rank>)', not as unidentified.")
    }
  }

  if (identical(spec$weight_type, "rra") && !is.null(spec$weight)) {
    ra <- .dv_add_rra(data, spec)
    data <- ra$data; spec <- ra$spec
    if (verbose) message("Reads turned into relative read abundance per sample (column `",
                         spec$weight, "`).")
  }

  out <- list(data = data, spec = spec, ranks = ranks,
              taxonomy_source = taxonomy, taxonomy_log = tax_log,
              stomachs = .dv_prep_stomachs(stomachs, spec, data, empty_col))
  class(out) <- "dietview_prep"
  attr(out, "lineage_gaps") <- n_gap
  out
}

# Internal: fill each empty rank that has an identified rank below it with
# "<nearest named coarser label> (no <rank>)". Trailing empty ranks stay NA.
# The number of filled cells per rank is returned as attr "lineage_gaps".
.dv_fill_gaps <- function(data, ranks) {
  K <- length(ranks); n <- nrow(data)
  n_gap <- stats::setNames(integer(K), ranks)
  finer <- rep(FALSE, n)
  has_finer <- vector("list", K)
  for (j in rev(seq_len(K))) {
    has_finer[[j]] <- finer
    v <- as.character(data[[ranks[j]]])
    finer <- finer | (!is.na(v) & v != "")
  }
  anc <- rep(NA_character_, n)
  for (j in seq_len(K)) {
    v <- as.character(data[[ranks[j]]])
    fill <- (is.na(v) | v == "") & has_finer[[j]]
    if (any(fill)) {
      v[fill] <- .dv_gap_label(anc[fill], ranks[j])
      data[[ranks[j]]] <- v
      n_gap[j] <- sum(fill)
    }
    real <- !is.na(v) & v != "" & !.dv_is_gap(v)
    anc[real] <- v[real]
  }
  attr(data, "lineage_gaps") <- n_gap
  data
}

# Match types written by dv_taxonomy_worms() and dv_taxonomy_gbif(), in display
# order ("higherrank" is GBIF only).
.DV_MATCH_TYPES <- c("id", "id_synonym", "id_unchecked", "id_fallback_name",
                     "exact", "fuzzy", "higherrank", "unresolved")

#' @export
print.dietview_prep <- function(x, ...) {
  cat("<dietview_prep>\n")
  cat("  records   :", nrow(x$data), "\n")
  cat(sprintf("  %-10s:", .dv_unit(x$spec, 2L)), length(unique(x$data[[x$spec$stomach]])), "\n")
  cat("  predators :", length(unique(x$data[[x$spec$predator]])), "\n")
  cat("  ranks     :", paste(x$ranks, collapse = " > "), "\n")
  cat("  covariates:", paste(x$spec$covariates, collapse = ", "), "\n")
  if (!is.null(x$taxonomy_source))
    cat("  source    :", x$taxonomy_source, "\n")
  st <- .dv_stomach_status(x)
  if (!is.null(st))
    cat("  examined  :", sum(st$status != "unknown"), paste0(.dv_unit(x$spec, 2L), ","),
        sum(st$status == "empty"), "empty",
        if (any(st$status == "unknown")) paste0("(", sum(st$status == "unknown"), " of unknown status)"),
        "\n")
  if (!is.null(x$taxonomy_log)) {
    tb <- table(factor(x$taxonomy_log$match_type, levels = .DV_MATCH_TYPES))
    cat("  taxonomy  : ", paste(sprintf("%s=%d", names(tb), as.integer(tb)),
                                collapse = ", "), "\n", sep = "")
    if (nrow(.dv_review_rows(x$taxonomy_log)) > 0)
      cat("              review: dv_taxonomy_report(prep)\n")
  }
  invisible(x)
}

# Internal: check and standardise the table of examined stomachs: the stomach,
# predator and covariate columns it has, plus a logical `empty_flag` (NA when
# no `empty_col` is given). Attribute "flagged" records whether a flag exists.
.dv_prep_stomachs <- function(stomachs, spec, data, empty_col = NULL) {
  if (is.null(stomachs)) {
    if (!is.null(empty_col)) stop("`empty_col` needs `stomachs`.", call. = FALSE)
    return(NULL)
  }
  if (!is.data.frame(stomachs)) stop("`stomachs` must be a data.frame.", call. = FALSE)
  st <- as.data.frame(stomachs)
  sid <- spec$stomach
  if (!sid %in% names(st))
    stop("`stomachs` must contain the stomach column `", sid, "`.", call. = FALSE)
  ids <- as.character(st[[sid]])
  if (anyNA(ids)) stop("`stomachs` has stomachs without an identifier.", call. = FALSE)
  dup <- unique(ids[duplicated(ids)])
  if (length(dup))
    stop("`stomachs` must have one row per stomach; duplicated: ",
         paste(utils::head(dup, 3), collapse = ", "), call. = FALSE)
  ex3 <- function(x) paste(utils::head(x, 3), collapse = ", ")
  d_ids <- as.character(data[[sid]])
  absent <- setdiff(unique(d_ids[!is.na(d_ids)]), ids)
  if (length(absent))
    warning(length(absent), " stomach(s) have prey records but are absent from ",
            "`stomachs` (e.g. ", ex3(absent), "); they are counted as examined and ",
            "non-empty.", call. = FALSE)
  if (is.null(spec$predator) || !spec$predator %in% names(st))
    warning("`stomachs` has no predator column `", spec$predator, "`: stomachs ",
            "without records cannot be assigned to a predator.", call. = FALSE)
  keep <- intersect(c(sid, spec$predator, spec$covariates), names(st))
  out <- st[, keep, drop = FALSE]
  out[[sid]] <- ids
  pcol <- spec$predator
  if (!is.null(pcol) && pcol %in% names(st) && pcol %in% names(data)) {
    rec_pred <- as.character(data[[pcol]])[match(ids, d_ids)]
    st_pred <- as.character(out[[pcol]])
    mism <- !is.na(rec_pred) & !is.na(st_pred) & rec_pred != st_pred
    if (any(mism)) {
      warning(sum(mism), " stomach(s) have a different predator in `stomachs` than ",
              "in the records (e.g. ", ex3(ids[mism]), "); the predator of the ",
              "records is used.", call. = FALSE)
      st_pred[mism] <- rec_pred[mism]
      out[[pcol]] <- st_pred
    }
  }
  if (is.null(empty_col)) {
    out$empty_flag <- NA
  } else {
    if (!empty_col %in% names(st))
      stop("`empty_col` `", empty_col, "` is not a column of `stomachs`.", call. = FALSE)
    v <- st[[empty_col]]
    out$empty_flag <- if (is.numeric(v)) v != 0 else as.logical(v)
    bad <- out$empty_flag %in% TRUE & ids %in% as.character(data[[sid]])
    if (any(bad))
      warning(sum(bad), " stomach(s) flagged empty have prey records; they are ",
              "counted as non-empty.", call. = FALSE)
  }
  attr(out, "flagged") <- !is.null(empty_col)
  out
}

# Internal: the examined stomachs of a prep with their status against the
# current prep$data: "with_records", "empty" or "unknown" (no record and not
# flagged empty, when a flag exists). Only predators present in the data are
# kept; stomachs of the data missing from the table are added as examined.
# NULL when the prep has no stomach table.
.dv_stomach_status <- function(prep) {
  st <- prep$stomachs
  if (is.null(st)) return(NULL)
  sid <- prep$spec$stomach; pcol <- prep$spec$predator
  d <- prep$data
  has_pred <- !is.null(pcol) && pcol %in% names(st) && pcol %in% names(d)
  if (has_pred)
    st <- st[as.character(st[[pcol]]) %in% unique(as.character(d[[pcol]])), , drop = FALSE]
  d_ids <- as.character(d[[sid]])
  extra <- setdiff(unique(d_ids), st[[sid]])
  if (length(extra)) {
    first <- d[match(extra, d_ids), intersect(names(st), names(d)), drop = FALSE]
    first[[sid]] <- extra
    first$empty_flag <- NA
    st <- dplyr::bind_rows(st, first)
  }
  has <- st[[sid]] %in% d_ids
  flagged <- isTRUE(attr(prep$stomachs, "flagged"))
  st$status <- ifelse(has, "with_records",
               ifelse(!flagged | st$empty_flag %in% TRUE, "empty", "unknown"))
  st
}

# Internal: reads -> per-sample proportions (relative read abundance). The new
# column replaces `weight` in the spec; the raw reads column is kept as
# `weight_raw`. Samples whose reads sum to 0 contribute nothing, with a warning.
.dv_add_rra <- function(data, spec) {
  raw <- spec$weight
  v <- .dv_as_num(data[[raw]]); v[is.na(v)] <- 0
  sid <- as.character(data[[spec$stomach]])
  tot <- stats::ave(v, sid, FUN = sum)
  zero <- unique(sid[tot == 0])
  if (length(zero))
    warning(length(zero), " sample(s) have no reads (e.g. ",
            paste(utils::head(zero, 3), collapse = ", "),
            "); they contribute nothing to the relative read abundance.", call. = FALSE)
  new <- "rra"
  while (new %in% names(data)) new <- paste0(new, "_")
  data[[new]] <- ifelse(tot > 0, v / tot, 0)
  spec$weight_raw <- raw
  spec$weight <- new
  list(data = data, spec = spec)
}
