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
#'     (`"id_unchecked"`). If WoRMS does not know the AphiaID at all (both its
#'     record and its classification come back "no content"), the prey name
#'     is matched instead, as below, and the match is logged as
#'     `"id_fallback_name"`;
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
#' Requires the \pkg{worrms} package and internet access. Requests are
#' batched: records are read for chunks of AphiaIDs ([worrms::wm_record()]),
#' names are matched in chunks ([worrms::wm_records_names()],
#' [worrms::wm_records_taxamatch()]) and classifications are requested per
#' chunk ([worrms::wm_classification_()]); the chunk size is
#' `getOption("DietView.worms_chunk", 50)`. A failed request is retried up to
#' `getOption("DietView.worms_retries", 3)` times, waiting 1, 2, 4 ... seconds
#' between attempts; a "no match" answer from WoRMS (HTTP 204) is final and
#' not retried. Successful lookups are cached to disk, so re-runs and other
#' surveys do not requery. Lookups that still fail (timeout, no network,
#' server error, an AphiaID WoRMS does not know) are never cached: they are
#' flagged with `lineage_ok = FALSE` and a warning, and are retried on the next
#' run.
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
#'   ("id", "id_synonym", "id_unchecked", "id_fallback_name", "exact",
#'   "fuzzy", "unresolved"),
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
    # an unreadable file is replaced at the end of the run
    dirty <- length(cache) != n_read || isTRUE(attr(cache, "unreadable"))
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

  retries <- max(0L, as.integer(getOption("DietView.worms_retries", 3L)))
  chunk_size <- max(1L, as.integer(getOption("DietView.worms_chunk", 50L)))
  chunks <- function(x) if (length(x)) unname(split(x, ceiling(seq_along(x) / chunk_size))) else list()
  ask <- function(f) .dv_worms_try(f, retries)

  # ---- 1. records of the known AphiaIDs, in chunks (cached) ------------------
  # status per AphiaID: "ok", "unknown" (WoRMS has no such ID) or "failed"
  rec <- list(); rec_status <- character(0)
  fetch_records <- function(ids) {
    for (id in ids) {
      hit <- cache_get(paste0("rec:", id))
      if (!is.null(hit)) { rec[[as.character(id)]] <<- hit$v; rec_status[[as.character(id)]] <<- "ok" }
    }
    todo <- ids[!as.character(ids) %in% names(rec_status)]
    for (ch in chunks(todo)) {
      if (verbose) message(" WoRMS records: ", length(ch), " AphiaID(s)")
      r <- ask(function() worrms::wm_record(as.integer(ch)))
      if (isTRUE(r$failed)) { rec_status[as.character(ch)] <<- "failed"; next }
      df <- if (isTRUE(r$no_match)) NULL else as.data.frame(r$value)
      for (id in ch) {
        j <- if (is.null(df) || !"AphiaID" %in% names(df)) integer(0) else which(df$AphiaID %in% id)
        if (!length(j)) { rec_status[[as.character(id)]] <<- "unknown"; next }
        j <- j[1]
        out <- list(
          name       = as.character(df$scientificname[j]),
          valid      = suppressWarnings(as.integer(df$valid_AphiaID[j])),
          valid_name = as.character(df$valid_name[j]))
        cache_set(paste0("rec:", id), out)
        rec[[as.character(id)]] <<- out; rec_status[[as.character(id)]] <<- "ok"
      }
    }
  }

  # ---- 2. lineages of AphiaIDs, in chunks (only successes are cached) --------
  # status per AphiaID: "ok", "no_match" or "failed"
  lin <- list(); lin_status <- character(0)
  fetch_lineages <- function(ids) {
    ids <- unique(ids[!is.na(ids)])
    ids <- ids[!as.character(ids) %in% names(lin_status)]
    for (id in ids) {
      hit <- cache_get(paste0("id:", id))
      # an entry cached with fewer ranks than requested now is fetched again
      if (!is.null(hit) && all(ranks %in% names(hit$v))) {
        lin[[as.character(id)]] <<- hit; lin_status[[as.character(id)]] <<- "ok"
      }
    }
    todo <- ids[!as.character(ids) %in% names(lin_status)]
    for (ch in chunks(todo)) {
      if (verbose) message(" WoRMS classifications: ", length(ch), " AphiaID(s)")
      got <- .dv_worms_classify(ch, retries)
      for (id in as.character(ch)) {
        s <- got$status[[id]]
        if (s == "ok") {
          cl <- got$rows[got$rows$id == id, , drop = FALSE]
          out <- stats::setNames(rep(NA_character_, length(ranks)), ranks)
          rk <- tolower(cl$rank)
          for (r in ranks) {
            h <- cl$scientificname[rk == r]
            if (length(h)) out[[r]] <- h[1]
          }
          cache_set(paste0("id:", id), out)
          lin[[id]] <<- list(v = out, t = now)
        }
        lin_status[[id]] <<- s
      }
    }
  }

  # ---- 3. names -> record (exact, then TAXAMATCH), in chunks (cached) --------
  # status per name: "ok", "no_match" or "failed"; unaccepted -> valid
  nm_res <- list(); nm_status <- character(0)
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
  # the key carries every option that changes the answer
  name_key <- function(nm) paste0("nm:", tolower(nm), if (fuzzy) ":f" else ":e",
                                  if (marine_only) ":m" else ":a")
  name_pass <- function(nms, fun, type) {
    for (ch in chunks(nms)) {
      if (verbose) message(" WoRMS names (", type, "): ", length(ch), " name(s)")
      r <- ask(function() fun(ch, marine_only = marine_only))
      if (isTRUE(r$failed)) { nm_status[ch] <<- "failed"; next }
      lst <- if (isTRUE(r$no_match)) vector("list", length(ch)) else r$value
      for (k in seq_along(ch)) {
        p <- if (k <= length(lst)) pick(lst[[k]], type) else NULL
        if (!is.null(p)) {
          nm_res[[ch[k]]] <<- p; nm_status[[ch[k]]] <<- "ok"
          cache_set(name_key(ch[k]), p)
        }
      }
    }
  }
  match_names <- function(nms) {
    nms <- unique(nms[!is.na(nms) & nzchar(nms)])
    nms <- nms[!nms %in% names(nm_status)]
    for (nm in nms) {
      hit <- cache_get(name_key(nm))
      if (!is.null(hit)) { nm_res[[nm]] <<- hit$v; nm_status[[nm]] <<- "ok" }
    }
    # exact: wm_records_names() matches the name as written (no wildcard)
    name_pass(nms[!nms %in% names(nm_status)], worrms::wm_records_names, "exact")
    # fuzzy: TAXAMATCH, which tolerates misspellings (a LIKE search does not)
    if (isTRUE(fuzzy))
      name_pass(nms[!nms %in% names(nm_status)], worrms::wm_records_taxamatch, "fuzzy")
    left <- nms[!nms %in% names(nm_status)]
    nm_status[left] <<- "no_match"
  }

  # ---- resolve: records, their lineages, then names, then those lineages -----
  aphia_in <- suppressWarnings(as.integer(keys$prey_id))
  name_in  <- trimws(as.character(keys$prey_name))
  has_name <- !is.na(name_in) & nzchar(name_in)
  fetch_records(unique(aphia_in[!is.na(aphia_in)]))
  used_id <- vapply(seq_len(n), function(i) {
    a <- aphia_in[i]
    if (is.na(a)) return(NA_integer_)
    r <- rec[[as.character(a)]]
    if (!is.null(r) && !is.na(r$valid)) r$valid else a
  }, integer(1))
  fetch_lineages(used_id)
  # an AphiaID WoRMS does not know (no record and no classification) falls
  # back to the prey name
  fallback <- !is.na(aphia_in) & has_name &
    rec_status[as.character(aphia_in)] %in% "unknown" &
    lin_status[as.character(used_id)] %in% "no_match"
  match_names(name_in[(is.na(aphia_in) & has_name) | fallback])
  fetch_lineages(vapply(nm_res, function(m) m$aphia, integer(1)))

  n_name_fail <- 0L
  for (i in seq_len(n)) {
    aphia <- aphia_in[i]; nm <- name_in[i]
    by_name <- FALSE
    if (!is.na(aphia)) {
      s <- rec_status[[as.character(aphia)]]
      r <- rec[[as.character(aphia)]]
      used <- used_id[i]
      keys$aphia_used[i]   <- used
      keys$match_type[i]   <- if (s != "ok") "id_unchecked"
                              else if (used != aphia) "id_synonym" else "id"
      keys$matched_name[i] <- if (s == "ok") r$valid_name else NA_character_
      if (s == "ok" && !is.na(r$name) && has_name[i])
        keys$name_check[i] <- if (tolower(nm) == tolower(r$name)) "agrees" else "differs"
      by_name <- fallback[i]
    } else if (has_name[i]) {
      by_name <- TRUE
    }
    if (by_name) {
      ms <- nm_status[[nm]]
      keys$aphia_used[i] <- NA_integer_
      if (ms == "failed") {
        keys$lineage_ok[i] <- FALSE
        n_name_fail <- n_name_fail + 1L
      } else if (ms == "ok") {
        m <- nm_res[[nm]]
        keys$aphia_used[i]   <- m$aphia
        keys$match_type[i]   <- if (!is.na(aphia)) "id_fallback_name" else m$type
        keys$matched_name[i] <- m$name
        keys$n_candidates[i] <- as.integer(m$n_candidates)
        keys$homonym[i]      <- isTRUE(m$homonym)
      } else {
        keys$match_type[i] <- "unresolved"
      }
    }

    if (!is.na(keys$aphia_used[i])) {
      id <- as.character(keys$aphia_used[i])
      ok <- identical(lin_status[id][[1]], "ok")
      keys$lineage_ok[i] <- ok
      if (ok) {
        for (r in ranks) keys[[r]][i] <- lin[[id]]$v[[r]]
        keys$retrieved[i] <- format(lin[[id]]$t, "%Y-%m-%d")
      }
    }
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
  if (is.list(x)) x else structure(list(), unreadable = TRUE)
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

# Internal: TRUE when a worrms condition means "WoRMS has no such name or ID"
# (HTTP 204, "No Content"), as opposed to a failed request. The HTTP status is
# used when the condition carries it (a `status_code` or `status` field, also
# inside `response`, or an `http_204` class); worrms 0.4 raises plain errors
# whose only trace of the status is the message "(204) No Content - ...", so
# the message is the fallback.
.dv_is_no_match <- function(e) {
  if (inherits(e, "http_204")) return(TRUE)
  st <- e$status_code %||% e$status %||%
    (if (is.list(e$response)) e$response$status_code %||% e$response$status)
  st <- suppressWarnings(as.integer(st))
  if (length(st) == 1L && !is.na(st)) return(st == 204L)
  grepl("\\(204\\)|no content", conditionMessage(e), ignore.case = TRUE)
}

# Internal: run one WoRMS request, retrying a failed one up to `retries` times
# with exponential backoff (1, 2, 4 s, ...). A "no match" answer is final.
# Returns list(value =), list(no_match = TRUE) or list(failed = TRUE, error =).
.dv_worms_try <- function(f, retries = 0L) {
  for (a in 0:retries) {
    if (a > 0L) .dv_sleep(2^(a - 1L))
    res <- tryCatch(list(value = f()), error = function(e) e)
    if (!inherits(res, "error")) return(res)
    if (.dv_is_no_match(res)) return(list(no_match = TRUE))
  }
  list(failed = TRUE, error = conditionMessage(res))
}

# Internal: kept apart so that tests do not wait.
.dv_sleep <- function(seconds) Sys.sleep(seconds)

# Internal: classifications of a chunk of AphiaIDs with
# worrms::wm_classification_(), which reports a failed ID as a warning and
# leaves it out. IDs whose warning is a "no match" are final; other missing
# IDs are requested again (backoff as in .dv_worms_try()). Returns the rows
# (id, rank, scientificname) and a status per ID: "ok", "no_match" or
# "failed".
.dv_worms_classify <- function(ids, retries = 0L) {
  key <- as.character(ids)
  status <- stats::setNames(rep("failed", length(key)), key)
  rows <- NULL
  pending <- key
  for (a in 0:retries) {
    if (!length(pending)) break
    if (a > 0L) .dv_sleep(2^(a - 1L))
    warns <- list()
    df <- tryCatch(withCallingHandlers(
      worrms::wm_classification_(id = as.integer(pending)),
      warning = function(w) {
        warns[[length(warns) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }), error = function(e) e)
    if (inherits(df, "error")) {
      if (.dv_is_no_match(df)) { status[pending] <- "no_match"; pending <- character(0) }
      next
    }
    df <- as.data.frame(df)
    got <- if (nrow(df) && "id" %in% names(df)) intersect(pending, as.character(df$id)) else character(0)
    if (length(got)) {
      sel <- as.character(df$id) %in% got
      rows <- rbind(rows, data.frame(id = as.character(df$id[sel]), rank = df$rank[sel],
                                     scientificname = df$scientificname[sel],
                                     stringsAsFactors = FALSE))
      status[got] <- "ok"
    }
    still <- setdiff(pending, got)
    no_match <- vapply(still, function(id) any(vapply(warns, function(w)
      .dv_is_no_match(w) && grepl(paste0("(^|[^0-9])", id, "$"), conditionMessage(w)),
      logical(1))), logical(1))
    status[still[no_match]] <- "no_match"
    pending <- still[!no_match]
  }
  list(rows = rows, status = status)
}

# Internal: rows of a taxonomy log (or of dv_taxonomy_worms() keys) that need a
# human eye. Columns missing from the log count as "no problem".
.dv_review_rows <- function(log) {
  col <- function(nm) if (is.null(log[[nm]])) rep(NA, nrow(log)) else log[[nm]]
  keep <- col("match_type") %in% c("fuzzy", "unresolved", "id_synonym", "id_unchecked",
                                    "id_fallback_name") |
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
#' to the accepted one), whose record could not be read (`"id_unchecked"`)
#' or that WoRMS does not know, so the prey name was used instead
#' (`"id_fallback_name"`),
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
