#' Resolve prey to the WoRMS classification (id, exact name, then fuzzy)
#'
#' Matches each unique prey to the World Register of Marine Species and returns
#' its lineage for the declared ranks. Matching proceeds in this order:
#' \enumerate{
#'   \item **id** - the AphiaID is already known (`prey_id`). Its WoRMS record
#'     is read: an unaccepted AphiaID is followed to its accepted (valid) one
#'     (`"id_synonym"`), and the prey name stored with it is compared with the
#'     name WoRMS gives that AphiaID (`name_check`: "agrees" or "differs"). If
#'     the record cannot be read, the AphiaID is used as given
#'     (`"id_unchecked"`);
#'   \item **exact** - the prey name matches a WoRMS name exactly;
#'   \item **fuzzy** - (if `fuzzy = TRUE`) WoRMS TAXAMATCH
#'     ([worrms::wm_records_taxamatch()]) proposes the closest name, which can
#'     rescue a misspelling;
#'   \item **unresolved** - nothing matched; all ranks stay `NA`.
#' }
#' Unaccepted names are followed to their accepted (valid) AphiaID before the
#' lineage is fetched. Every prey carries a provenance record (`match_type`,
#' `name_check`, `matched_name`, `aphia_used`, `n_candidates`, `homonym`,
#' `lineage_ok`, `retrieved`) so doubtful matches can be reviewed and corrected -
#' see [dv_taxonomy_report()]. Nothing is guessed silently: a fuzzy match is
#' flagged, a name with several accepted WoRMS records is flagged as a possible
#' homonym, and an unresolved prey keeps `NA` ranks and shows up as the explicit
#' unidentified category downstream.
#'
#' Requires the \pkg{worrms} package and internet access. Successful lookups
#' are cached to disk, so re-runs and other surveys do not requery. Failed
#' lookups (timeout, no network, server error, an AphiaID WoRMS does not know)
#' are never cached: they are flagged with `lineage_ok = FALSE` and a warning,
#' and are retried on the next run.
#'
#' The cache is managed: entries older than `cache_max_age` days are removed
#' from the file each time it is read (and fetched again when needed), as are
#' malformed (undated) entries. An unreadable cache file is
#' ignored with a warning and rebuilt. The file is rewritten only when something
#' changed, even if the run is interrupted, and [dv_cache_clear()] deletes it.
#'
#' @param keys Data.frame with columns `prey_id` (AphiaID, may be NA) and
#'   `prey_name` (may be NA); one row per unique prey. Other columns are kept.
#' @param ranks Ranks to keep (default the seven flagship ranks).
#' @param cache_dir Directory for the on-disk cache. `NULL` disables caching.
#' @param fuzzy If `TRUE` (default), fall back to WoRMS TAXAMATCH fuzzy name
#'   matching when the exact name fails. Set `FALSE` for exact-only,
#'   conservative matching.
#' @param marine_only Restrict WoRMS name matching to marine taxa.
#' @param cache_max_age Maximum age, in days, of a cached lookup before it is
#'   fetched again (default 180). `Inf` trusts the cache forever.
#' @param verbose Print progress.
#' @return `keys` with one column per rank plus `aphia_used`, `match_type`
#'   ("id", "id_synonym", "id_unchecked", "exact", "fuzzy", "unresolved"),
#'   `name_check`, `matched_name`, `n_candidates` (WoRMS records returned for a
#'   name), `homonym` (more than one accepted record for that name),
#'   `lineage_ok` (`TRUE`/`FALSE` once a classification was requested, `NA`
#'   otherwise) and `retrieved` (date the lineage was fetched from WoRMS).
#' @examples
#' \dontrun{
#' # needs the 'worrms' package and internet access
#' keys <- data.frame(
#'   prey_id   = c(126436, NA),
#'   prey_name = c("Gadus morhua", "Crangon crangon"),
#'   stringsAsFactors = FALSE
#' )
#' dv_taxonomy_worms(keys)
#'
#' # the prey keys of the ICES cod records
#' cod <- ices_diet[ices_diet$predator_common == "Atlantic cod", ]
#' keys <- unique(data.frame(prey_id = cod$prey_aphia_id,
#'                           prey_name = cod$prey_name))
#' lin <- dv_taxonomy_worms(keys)
#' table(lin$match_type)
#' }
#' @export
dv_taxonomy_worms <- function(keys,
                              ranks = c("kingdom", "phylum", "class", "order",
                                        "family", "genus", "species"),
                              cache_dir = tools::R_user_dir("DietView", "cache"),
                              fuzzy = TRUE,
                              marine_only = TRUE,
                              cache_max_age = 180,
                              verbose = TRUE) {
  if (!requireNamespace("worrms", quietly = TRUE)) {
    stop("Install the 'worrms' package to use WoRMS taxonomy retrieval.", call. = FALSE)
  }
  keys <- as.data.frame(keys, stringsAsFactors = FALSE)
  n <- nrow(keys)
  # rep(..., n) so that an empty `keys` gives an empty result, not an error
  for (r in ranks) keys[[r]] <- rep(NA_character_, n)
  keys$aphia_used   <- rep(NA_integer_, n)
  keys$match_type   <- rep("unresolved", n)
  keys$name_check   <- rep(NA_character_, n)
  keys$matched_name <- rep(NA_character_, n)
  keys$n_candidates <- rep(NA_integer_, n)
  keys$homonym      <- rep(FALSE, n)
  keys$lineage_ok   <- rep(NA, n)                    # TRUE / FALSE once a lookup is tried
  keys$retrieved    <- rep(NA_character_, n)

  # ---- cache ---------------------------------------------------------------
  # Entries are list(v = value, t = time of the WoRMS call). Only successful
  # lookups are stored.
  now <- Sys.time()
  cache_file <- NULL; cache <- list(); dirty <- FALSE
  if (!is.null(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, .DV_CACHE_FILE)
    cache <- .dv_cache_read(cache_file)
    # expired and malformed (undated) entries are removed, so the file does not grow
    # without bound
    n_read <- length(cache)
    cache <- .dv_cache_prune(cache, now, cache_max_age)
    dirty <- length(cache) != n_read
    # saved even on error/interrupt, and only when something changed
    on.exit(if (dirty) .dv_cache_write(cache, cache_file), add = TRUE)
  }
  cache_get <- function(key) {
    e <- cache[[key]]
    if (!is.list(e) || is.null(e$t)) return(NULL)     # missing or malformed (undated)
    age <- as.numeric(difftime(now, e$t, units = "days"))
    if (is.finite(cache_max_age) && age > cache_max_age) return(NULL)
    e
  }
  cache_set <- function(key, v) {
    cache[[key]] <<- list(v = v, t = now)
    dirty <<- TRUE
  }

  # ---- record for one AphiaID (cached): status, name, accepted ID ----------
  record_for <- function(aphia) {
    key <- paste0("rec:", aphia)
    hit <- cache_get(key)
    if (!is.null(hit)) return(hit$v)
    rec <- tryCatch(worrms::wm_record(as.integer(aphia)), error = function(e) NULL)
    first <- function(x) if (length(x)) x[[1]] else NA
    if (is.null(rec) || !NROW(rec)) return(NULL)      # failure: NOT cached
    out <- list(
      name       = as.character(first(rec$scientificname)),
      valid      = suppressWarnings(as.integer(first(rec$valid_AphiaID))),
      valid_name = as.character(first(rec$valid_name)))
    cache_set(key, out)
    out
  }

  # ---- lineage for one AphiaID (only successes are cached) ------------------
  lineage_for <- function(aphia) {
    key <- paste0("id:", aphia)
    hit <- cache_get(key)
    # an entry cached with fewer ranks than requested now is fetched again
    if (!is.null(hit) && all(ranks %in% names(hit$v))) return(hit)
    cl <- tryCatch(worrms::wm_classification(as.integer(aphia)),
                   error = function(e) NULL)
    if (is.null(cl) || !NROW(cl)) return(NULL)        # failure: NOT cached
    out <- stats::setNames(rep(NA_character_, length(ranks)), ranks)
    rk <- tolower(cl$rank)
    for (r in ranks) {
      hit <- cl$scientificname[rk == r]
      if (length(hit)) out[[r]] <- hit[1]
    }
    cache_set(key, out)
    list(v = out, t = now)
  }

  # ---- name -> record (exact, then TAXAMATCH); follows unaccepted -> valid --
  match_name <- function(nm) {
    # the key carries every option that changes the answer
    key <- paste0("nm:", tolower(nm), if (fuzzy) ":f" else ":e",
                  if (marine_only) ":m" else ":a")
    hit <- cache_get(key)
    if (!is.null(hit)) return(hit$v)

    pick <- function(df, type) {
      if (is.null(df) || !is.data.frame(df) || !nrow(df)) return(NULL)
      # prefer an accepted record; otherwise follow valid_AphiaID
      ok <- if ("status" %in% names(df)) which(df$status == "accepted") else integer(0)
      i  <- if (length(ok)) ok[1] else 1L
      id <- if ("valid_AphiaID" %in% names(df) && !is.na(df$valid_AphiaID[i]))
        df$valid_AphiaID[i] else df$AphiaID[i]
      nmm <- if ("valid_name" %in% names(df) && !is.na(df$valid_name[i]))
        df$valid_name[i] else df$scientificname[i]
      list(aphia = as.integer(id), name = as.character(nmm), type = type,
           n_candidates = nrow(df), homonym = length(ok) > 1L)
    }
    # WoRMS answers "no match" with an HTTP 204 error; any other error (timeout,
    # server error) means the lookup itself failed and must not look like a
    # genuine non-match
    failed <- FALSE
    ask <- function(fun, type) tryCatch({
      lst <- fun(name = nm, marine_only = marine_only)
      df <- if (length(lst)) lst[[1]] else NULL
      pick(df, type)
    }, error = function(e) {
      if (!.dv_is_no_match(e)) failed <<- TRUE
      NULL
    })

    # exact: wm_records_names() matches the name as written (no wildcard)
    res <- ask(worrms::wm_records_names, "exact")
    # fuzzy: TAXAMATCH, which tolerates misspellings (a LIKE search does not)
    if (is.null(res) && isTRUE(fuzzy))
      res <- ask(worrms::wm_records_taxamatch, "fuzzy")

    if (!is.null(res)) cache_set(key, res)
    else if (failed) res <- list(failed = TRUE)     # failure: NOT cached
    res
  }

  # ---- resolve each prey ---------------------------------------------------
  n_name_fail <- 0L
  for (i in seq_len(n)) {
    aphia <- suppressWarnings(as.integer(keys$prey_id[i]))
    nm    <- trimws(as.character(keys$prey_name[i]))

    if (!is.na(aphia)) {
      rec  <- record_for(aphia)
      used <- if (!is.null(rec) && !is.na(rec$valid)) rec$valid else aphia
      keys$aphia_used[i]   <- used
      keys$match_type[i]   <- if (is.null(rec)) "id_unchecked"
                              else if (used != aphia) "id_synonym" else "id"
      keys$matched_name[i] <- if (!is.null(rec)) rec$valid_name else NA_character_
      if (!is.null(rec) && !is.na(rec$name) && !is.na(nm) && nzchar(nm))
        keys$name_check[i] <- if (tolower(nm) == tolower(rec$name)) "agrees" else "differs"
    } else if (!is.na(nm) && nzchar(nm)) {
      m <- match_name(nm)
      if (isTRUE(m$failed)) {
        keys$lineage_ok[i] <- FALSE
        n_name_fail <- n_name_fail + 1L
      } else if (!is.null(m)) {
        keys$aphia_used[i]   <- m$aphia
        keys$match_type[i]   <- m$type
        keys$matched_name[i] <- m$name
        keys$n_candidates[i] <- as.integer(m$n_candidates)
        keys$homonym[i]      <- isTRUE(m$homonym)
      }
    }

    if (!is.na(keys$aphia_used[i])) {
      lin <- lineage_for(keys$aphia_used[i])
      keys$lineage_ok[i] <- !is.null(lin)
      if (!is.null(lin)) {
        for (r in ranks) keys[[r]][i] <- lin$v[[r]]
        keys$retrieved[i] <- format(lin$t, "%Y-%m-%d")
      }
    }
    if (verbose && i %% 100 == 0) message(" resolved ", i, "/", n)
  }

  if (n_name_fail)
    warning(n_name_fail, " prey name(s) could not be looked up in WoRMS (network ",
            "or server error). They are left unresolved for now and were not ",
            "cached; run again to retry, and see dv_taxonomy_report().", call. = FALSE)
  n_fail <- sum(keys$lineage_ok %in% FALSE) - n_name_fail
  if (n_fail)
    warning(n_fail, " prey key(s) were matched but WoRMS returned no classification ",
            "(network or server error, or an ID WoRMS does not know). Their records are ",
            "unidentified at every rank for now. They were not cached; run again to retry, ",
            "and see dv_taxonomy_report().", call. = FALSE)

  if (verbose) {
    tb <- table(factor(keys$match_type, levels = .DV_MATCH_TYPES))
    message("WoRMS matching: ", paste(sprintf("%s=%d", names(tb), as.integer(tb)),
                                      collapse = ", "))
    if (nrow(.dv_review_rows(keys)) > 0)
      message("  -> review with dv_taxonomy_report(prep)")
  }
  keys
}

# ---- on-disk WoRMS cache ----------------------------------------------------

.DV_CACHE_FILE <- "worms_lineage.rds"

# Internal: read the cache; an unreadable file is ignored (and later replaced).
.dv_cache_read <- function(file) {
  if (!file.exists(file)) return(list())
  x <- tryCatch(readRDS(file), error = function(e) {
    warning("The WoRMS cache file '", file, "' could not be read (",
            conditionMessage(e), "); it is ignored and will be rebuilt.",
            call. = FALSE)
    NULL
  })
  if (is.list(x)) x else list()
}

# Internal: keep only dated entries no older than `max_age` days.
.dv_cache_prune <- function(cache, now, max_age) {
  if (!length(cache)) return(cache)
  keep <- vapply(cache, function(e) {
    if (!is.list(e) || is.null(e$t)) return(FALSE)
    !is.finite(max_age) ||
      as.numeric(difftime(now, e$t, units = "days")) <= max_age
  }, logical(1))
  cache[keep]
}

# Internal: write to a temporary file first, so an interrupted write never
# leaves a truncated cache behind.
.dv_cache_write <- function(cache, file) {
  tmp <- paste0(file, ".tmp")
  ok <- tryCatch({
    saveRDS(cache, tmp)
    file.rename(tmp, file)
  }, error = function(e) FALSE)
  if (!isTRUE(ok)) {
    unlink(tmp)
    warning("Could not write the WoRMS cache to '", file, "'.", call. = FALSE)
  }
  invisible(isTRUE(ok))
}

#' Delete the WoRMS lookup cache
#'
#' [dv_prepare()] and [dv_taxonomy_worms()] keep successful WoRMS lookups in a
#' cache file, by default in `tools::R_user_dir("DietView", "cache")`. Expired
#' entries are removed automatically; this function deletes the whole cache,
#' and the cache directory too if nothing else is left in it.
#'
#' @param cache_dir The cache directory, as given to [dv_prepare()].
#' @return `TRUE` if a cache file was deleted, `FALSE` otherwise, invisibly.
#' @examples
#' # a cache in a temporary folder, so the example leaves nothing behind
#' dir <- file.path(tempdir(), "dietview-cache")
#' dir.create(dir)
#' saveRDS(list(), file.path(dir, "worms_lineage.rds"))
#' dv_cache_clear(dir)
#' dir.exists(dir)
#' @export
dv_cache_clear <- function(cache_dir = tools::R_user_dir("DietView", "cache")) {
  f <- file.path(cache_dir, .DV_CACHE_FILE)
  had <- file.exists(f)
  if (had) unlink(f)
  if (dir.exists(cache_dir) &&
      !length(list.files(cache_dir, all.files = TRUE, no.. = TRUE)))
    unlink(cache_dir, recursive = TRUE)
  invisible(had)
}

# Internal: TRUE when a worrms error means "WoRMS has no such name" (HTTP 204,
# "No Content"), as opposed to a failed request.
.dv_is_no_match <- function(e) {
  grepl("204|no content|not found|no match", conditionMessage(e), ignore.case = TRUE)
}

# Internal: rows of a taxonomy log (or of dv_taxonomy_worms() keys) that need a
# human eye. Columns missing from the log count as "no problem".
.dv_review_rows <- function(log) {
  col <- function(nm) if (is.null(log[[nm]])) rep(NA, nrow(log)) else log[[nm]]
  keep <- col("match_type") %in% c("fuzzy", "unresolved", "id_synonym", "id_unchecked") |
    col("name_check") %in% "differs" |
    col("lineage_ok") %in% FALSE |
    col("homonym") %in% TRUE
  log[keep, , drop = FALSE]
}

#' Review doubtful prey matches
#'
#' Returns the prey whose taxonomy needs a human eye: fuzzy matches (WoRMS
#' TAXAMATCH proposed a close-but-not-identical name), unresolved prey (no
#' match), AphiaIDs that WoRMS treats as unaccepted (`"id_synonym"`, followed
#' to the accepted one) or whose record could not be read (`"id_unchecked"`),
#' AphiaIDs whose stored name differs from the WoRMS name (`name_check =
#' "differs"`), names with several accepted WoRMS records (`homonym`), and
#' matches for which WoRMS returned no classification (`lineage_ok = FALSE`,
#' usually a network or server error; run again to retry). Use it to audit the
#' enrichment, then correct anything wrong by supplying a lineage table
#' (`dv_prepare(taxonomy = "table")`) or fixing the source names.
#'
#' @param prep A `dietview_prep` produced with `taxonomy = "worms"`.
#' @param which Which rows to return: "review" (every doubtful row listed above,
#'   the default), "fuzzy", "unresolved", or "all".
#' @param file Optional CSV path to write the report to.
#' @return A data.frame with the prey name, the names seen under that key, what
#'   WoRMS matched, the match type and checks, the AphiaID used, the number of
#'   records affected, and the resolved ranks, sorted by number of records.
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
#' \dontrun{
#' # a WoRMS-prepared object carries a taxonomy log to review
#' # (needs the 'worrms' package and internet access)
#' cod <- dat[dat$predator_common == "Atlantic cod", ]
#' prep_worms <- dv_prepare(cod, spec, taxonomy = "worms")
#' dv_taxonomy_report(prep_worms, which = "review")
#' }
#' @export
dv_taxonomy_report <- function(prep,
                               which = c("review", "fuzzy", "unresolved", "all"),
                               file = NULL) {
  which <- match.arg(which)
  stopifnot(inherits(prep, "dietview_prep"))
  log <- prep$taxonomy_log
  if (is.null(log)) {
    stop("No taxonomy log: this object was not prepared with taxonomy = 'worms'.",
         call. = FALSE)
  }
  out <- switch(which,
                review     = .dv_review_rows(log),
                fuzzy      = log[log$match_type == "fuzzy", , drop = FALSE],
                unresolved = log[log$match_type == "unresolved", , drop = FALSE],
                all        = log)
  out <- out[order(-out$n_records), , drop = FALSE]
  if (!is.null(file)) utils::write.csv(out, file, row.names = FALSE)
  out
}
