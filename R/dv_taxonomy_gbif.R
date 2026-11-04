#' Resolve prey to the GBIF Backbone Taxonomy (key, exact name, then fuzzy)
#'
#' The terrestrial and freshwater counterpart of [dv_taxonomy_worms()]: matches
#' each unique prey to the GBIF Backbone Taxonomy, which covers all kingdoms,
#' and returns its lineage for the declared ranks. It follows the same rules
#' and returns the same provenance columns, so [dv_prepare()],
#' [dv_taxonomy_report()] and the rest of the package treat both sources alike.
#' Matching proceeds in this order:
#' \enumerate{
#'   \item **id** - a GBIF taxon key is already known (`prey_id`). Its record
#'     is read: a synonym is followed to its accepted taxon (`"id_synonym"`)
#'     and the prey name stored with it is compared with the GBIF name
#'     (`name_check`). If the record cannot be read, the key is left
#'     unresolved for now (`"id_unchecked"`, `lineage_ok = FALSE`). A key GBIF
#'     does not know falls back to the prey name (`"id_fallback_name"`);
#'   \item **exact** - the GBIF species-match service finds the name as
#'     written;
#'   \item **fuzzy** - (if `fuzzy = TRUE`) the service proposes a close name,
#'     which can rescue a misspelling;
#'   \item **higherrank** - the name itself is unknown but a coarser taxon in it
#'     is (e.g. the genus of an unknown species); the lineage stops at that
#'     rank, so the record shows as unidentified below it. A step up to a
#'     kingdom alone (what GBIF answers for "Plastic" with `kingdom =
#'     "Animalia"`) is treated as no match;
#'   \item **unresolved** - nothing matched; all ranks stay `NA`.
#' }
#' A name can belong to several taxa (Polychaeta is a class of worms and a
#' genus of flies). GBIF then steps up to their shared ancestor, or gives no
#' match. DietView looks at the alternatives GBIF lists: when exactly one of
#' them is an exact match to an accepted name (in `kingdom`, if given), it is
#' taken; when several are, the conservative GBIF answer is kept and the prey
#' is flagged as a possible `homonym`, to be settled by a lineage table.
#' A name matched as a synonym gets the classification of its accepted taxon.
#' Every match type other than `"id"` and `"exact"`, a name that differs from
#' the GBIF name, a match below `min_confidence` and a possible homonym are
#' listed by [dv_taxonomy_report()] for review.
#'
#' The GBIF Backbone has no class for some groups (ray-finned fishes, for
#' instance, sit directly under Chordata). With `dv_prepare(gaps = "label")`,
#' the default, such a missing rank is filled as `"Chordata (no class)"`
#' instead of looking unidentified.
#'
#' Needs internet access to `api.gbif.org` and no extra package. Successful
#' lookups are cached to disk, in their own file next to the WoRMS cache, with
#' the same expiry rules (`cache_max_age`); failed lookups are never cached and
#' are retried on the next run, `getOption("DietView.gbif_retries", 3)` times
#' per request with a 1, 2, 4 ... second backoff.
#'
#' @param keys Data.frame with columns `prey_id` (GBIF taxon key, may be `NA`)
#'   and `prey_name` (may be `NA`); one row per unique prey. Other columns are
#'   kept.
#' @param ranks Ranks to keep (default the seven flagship ranks). GBIF returns
#'   kingdom, phylum, class, order, family, genus and species; any other rank
#'   stays `NA`.
#' @param cache_dir Directory for the on-disk cache. `NULL` disables caching.
#' @param fuzzy If `TRUE` (default), accept fuzzy matches. `FALSE` asks GBIF
#'   for strict matching only.
#' @param kingdom Optional kingdom hint passed to GBIF (e.g. `"Animalia"`),
#'   which helps with names shared by a plant and an animal genus.
#' @param min_confidence GBIF confidence (0-100) below which a match is listed
#'   for review (default 90). The match is kept.
#' @param cache_max_age Maximum age, in days, of a cached lookup (default 180).
#' @param verbose Print progress.
#' @return `keys` with one column per rank plus `gbif_key`, `match_type`
#'   ("id", "id_synonym", "id_unchecked", "id_fallback_name", "exact",
#'   "fuzzy", "higherrank", "unresolved"), `name_check`, `matched_name`,
#'   `confidence`, `n_candidates` (exact-name candidates GBIF listed),
#'   `homonym`, `lineage_ok`, `retrieved` and `low_confidence`.
#' @seealso [dv_taxonomy_worms()] for marine prey; [dv_parse_lineage()] when
#'   the lineage already comes with the data (e.g. from a metabarcoding
#'   pipeline).
#' @examples
#' \dontrun{
#' # needs internet access
#' keys <- data.frame(prey_id   = c(NA, 8084280),
#'                    prey_name = c("Crangon vulgaris", "Gadus morhua"))
#' dv_taxonomy_gbif(keys)
#' }
#' @export
dv_taxonomy_gbif <- function(keys,
                             ranks = c("kingdom", "phylum", "class", "order",
                                       "family", "genus", "species"),
                             cache_dir = tools::R_user_dir("DietView", "cache"),
                             fuzzy = TRUE,
                             kingdom = NULL,
                             min_confidence = 90,
                             cache_max_age = 180,
                             verbose = TRUE) {
  keys <- as.data.frame(keys, stringsAsFactors = FALSE)
  n <- nrow(keys)
  if (is.null(keys$prey_id))   keys$prey_id   <- rep(NA, n)
  if (is.null(keys$prey_name)) keys$prey_name <- rep(NA_character_, n)
  for (r in ranks) keys[[r]] <- rep(NA_character_, n)
  keys$gbif_key     <- rep(NA_integer_, n)
  keys$match_type   <- rep("unresolved", n)
  keys$name_check   <- rep(NA_character_, n)
  keys$matched_name <- rep(NA_character_, n)
  keys$confidence   <- rep(NA_integer_, n)
  keys$n_candidates <- rep(NA_integer_, n)
  keys$homonym      <- rep(FALSE, n)
  keys$lineage_ok   <- rep(NA, n)
  keys$retrieved    <- rep(NA_character_, n)

  # ---- cache (same format and rules as the WoRMS cache) ----------------------
  now <- Sys.time()
  cache <- list(); dirty <- FALSE
  if (!is.null(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, .DV_GBIF_CACHE_FILE)
    cache <- .dv_cache_read(cache_file)
    n_read <- length(cache)
    cache <- .dv_cache_prune(cache, now, cache_max_age)
    dirty <- length(cache) != n_read || isTRUE(attr(cache, "unreadable"))
    on.exit(if (dirty) .dv_cache_write(cache, cache_file), add = TRUE)
  }
  cache_get <- function(key) {
    e <- cache[[key]]
    if (!is.list(e) || is.null(e$t)) return(NULL)
    if (is.finite(cache_max_age) &&
        as.numeric(difftime(now, e$t, units = "days")) > cache_max_age) return(NULL)
    e
  }
  cache_set <- function(key, v) { cache[[key]] <<- list(v = v, t = now); dirty <<- TRUE }
  retries <- max(0L, as.integer(getOption("DietView.gbif_retries", 3L)))

  # one taxon record -> lineage for the requested ranks
  lineage_of <- function(x) {
    out <- stats::setNames(rep(NA_character_, length(ranks)), ranks)
    for (r in intersect(ranks, .DV_GBIF_RANKS)) {
      v <- x[[r]]
      if (!is.null(v) && length(v) == 1L && !is.na(v) && nzchar(v)) out[[r]] <- as.character(v)
    }
    out
  }
  # the accepted name at the matched rank (a synonym's own name is not it)
  accepted_name <- function(x) {
    rk <- tolower(x$rank %||% "")
    v <- if (rk %in% .DV_GBIF_RANKS) x[[rk]] else NULL
    if (!is.null(v) && !is.na(v)) as.character(v) else as.character(x$canonicalName %||% NA)
  }

  # ---- 1. records of known keys ----------------------------------------------
  # result per key: list(status = "ok" | "unknown" | "failed", ...)
  by_key <- function(k) {
    ck <- paste0("gid:", k)
    hit <- cache_get(ck)
    if (!is.null(hit)) return(c(hit$v, list(status = "ok", t = hit$t)))
    r <- .dv_gbif_try(sprintf("%s/species/%s", .DV_GBIF_API, k), retries)
    if (isTRUE(r$failed)) return(list(status = "failed"))
    if (isTRUE(r$not_found) || is.null(r$value$key)) return(list(status = "unknown"))
    x <- r$value
    # a key from another checklist: use its Backbone counterpart
    if (!identical(x$datasetKey, .DV_GBIF_BACKBONE) && !is.null(x$nubKey) &&
        !identical(as.integer(x$nubKey), as.integer(k))) {
      r <- .dv_gbif_try(sprintf("%s/species/%s", .DV_GBIF_API, x$nubKey), retries)
      if (isTRUE(r$failed)) return(list(status = "failed"))
      if (isTRUE(r$not_found) || is.null(r$value$key)) return(list(status = "unknown"))
      x <- r$value
    }
    acc <- x$acceptedKey %||% x$key
    v <- list(name = as.character(x$canonicalName %||% NA),
              used = as.integer(acc),
              synonym = !is.null(x$acceptedKey) && !identical(as.integer(x$acceptedKey), as.integer(x$key)),
              matched = accepted_name(x),
              lineage = lineage_of(x))
    cache_set(ck, v)
    c(v, list(status = "ok", t = now))
  }

  # ---- 2. names -> species-match service -------------------------------------
  name_key <- function(nm) paste0("gnm:", tolower(nm), if (fuzzy) ":f" else ":s",
                                  ":", tolower(kingdom %||% ""))
  by_name <- function(nm) {
    hit <- cache_get(name_key(nm))
    if (!is.null(hit)) return(c(hit$v, list(status = "ok", t = hit$t)))
    q <- paste0("name=", utils::URLencode(nm, reserved = TRUE), "&verbose=true",
                if (!fuzzy) "&strict=true",
                if (!is.null(kingdom)) paste0("&kingdom=", utils::URLencode(kingdom, reserved = TRUE)))
    r <- .dv_gbif_try(sprintf("%s/species/match?%s", .DV_GBIF_API, q), retries)
    if (isTRUE(r$failed)) return(list(status = "failed"))
    x <- if (isTRUE(r$not_found)) list(matchType = "NONE") else r$value
    mt <- toupper(x$matchType %||% "NONE")
    note <- as.character(x$note %||% "")
    # exact, accepted candidates among the answer and its alternatives: one
    # such candidate is taken even when GBIF itself stepped up to a shared
    # ancestor (e.g. "Isopoda", an accepted order and a synonym genus); two or
    # more are a homonym, and the conservative answer of GBIF is kept
    cands <- c(list(x), x$alternatives %||% list())
    exact <- Filter(function(a) identical(toupper(a$matchType %||% ""), "EXACT") &&
                      !is.null(a$usageKey), cands)
    exact <- exact[!duplicated(vapply(exact, function(a) as.character(a$usageKey), ""))]
    acc <- Filter(function(a) toupper(a$status %||% "ACCEPTED") %in% c("ACCEPTED", "DOUBTFUL"),
                  exact)
    if (!is.null(kingdom))
      acc <- Filter(function(a) identical(tolower(a$kingdom %||% ""), tolower(kingdom)), acc)
    if (mt %in% c("HIGHERRANK", "NONE") && length(acc) == 1L) {
      x <- acc[[1]]; mt <- "EXACT"
    }
    homonym <- length(acc) >= 2L || grepl("multiple equal", note, ignore.case = TRUE)
    n_cand <- if (length(exact)) length(exact) else NA_integer_
    v <- if (mt == "NONE" || is.null(x$usageKey)) {
      list(type = "unresolved", used = NA_integer_, matched = NA_character_,
           confidence = suppressWarnings(as.integer(x$confidence %||% NA)),
           homonym = homonym, n_candidates = n_cand, lineage = NULL)
    } else {
      list(type = switch(mt, EXACT = "exact", FUZZY = "fuzzy",
                         HIGHERRANK = "higherrank", "fuzzy"),
           used = as.integer(x$acceptedUsageKey %||% x$usageKey),
           matched = accepted_name(x),
           confidence = suppressWarnings(as.integer(x$confidence %||% NA)),
           homonym = homonym, n_candidates = n_cand,
           lineage = lineage_of(x))
    }
    if (!fuzzy && v$type == "fuzzy") v$type <- "unresolved"
    # stepping up to a kingdom says nothing the name did not (e.g. "Plastic",
    # or "Unidentified material" with kingdom = "Animalia"): no match
    if (v$type == "higherrank" && identical(toupper(x$rank %||% ""), "KINGDOM"))
      v <- list(type = "unresolved", used = NA_integer_, matched = NA_character_,
                confidence = v$confidence, homonym = v$homonym,
                n_candidates = v$n_candidates, lineage = NULL)
    cache_set(name_key(nm), v)          # a "no match" answer is final, and cached
    c(v, list(status = "ok", t = now))
  }

  # ---- resolve -----------------------------------------------------------------
  id_in   <- suppressWarnings(as.integer(as.character(keys$prey_id)))
  name_in <- trimws(as.character(keys$prey_name))
  has_name <- !is.na(name_in) & nzchar(name_in)
  ids <- unique(id_in[!is.na(id_in)])
  if (verbose && length(ids)) message(" GBIF records: ", length(ids), " key(s)")
  rec <- stats::setNames(lapply(ids, by_key), as.character(ids))
  unknown_id <- !is.na(id_in) &
    vapply(as.character(id_in), function(k) identical(rec[[k]]$status, "unknown"), logical(1))
  todo_names <- unique(name_in[has_name & (is.na(id_in) | unknown_id)])
  if (verbose && length(todo_names)) message(" GBIF names: ", length(todo_names), " name(s)")
  nms <- stats::setNames(lapply(todo_names, by_name), todo_names)

  n_fail <- 0L
  set_lineage <- function(i, lin, t) {
    if (is.null(lin)) return(invisible())
    for (r in ranks) keys[[r]][i] <<- lin[[r]]
    keys$retrieved[i] <<- format(t, "%Y-%m-%d")
  }
  for (i in seq_len(n)) {
    use_name <- FALSE
    if (!is.na(id_in[i])) {
      x <- rec[[as.character(id_in[i])]]
      if (x$status == "ok") {
        keys$gbif_key[i]     <- x$used
        keys$match_type[i]   <- if (isTRUE(x$synonym)) "id_synonym" else "id"
        keys$matched_name[i] <- x$matched
        keys$lineage_ok[i]   <- TRUE
        if (has_name[i] && !is.na(x$name))
          keys$name_check[i] <- if (tolower(name_in[i]) == tolower(x$name)) "agrees" else "differs"
        set_lineage(i, x$lineage, x$t)
      } else if (x$status == "failed") {
        keys$gbif_key[i]   <- id_in[i]
        keys$match_type[i] <- "id_unchecked"
        keys$lineage_ok[i] <- FALSE
        n_fail <- n_fail + 1L
      } else {
        use_name <- has_name[i]
      }
    } else {
      use_name <- has_name[i]
    }
    if (use_name) {
      x <- nms[[name_in[i]]]
      if (x$status == "failed") {
        keys$lineage_ok[i] <- FALSE
        n_fail <- n_fail + 1L
        next
      }
      keys$homonym[i]      <- isTRUE(x$homonym)
      keys$confidence[i]   <- x$confidence
      keys$n_candidates[i] <- as.integer(x$n_candidates %||% NA_integer_)
      if (x$type == "unresolved") next
      keys$gbif_key[i]     <- x$used
      keys$match_type[i]   <- if (!is.na(id_in[i])) "id_fallback_name" else x$type
      keys$matched_name[i] <- x$matched
      keys$lineage_ok[i]   <- TRUE
      set_lineage(i, x$lineage, x$t)
    }
  }
  keys$low_confidence <- !is.na(keys$confidence) & keys$confidence < min_confidence &
    keys$match_type != "unresolved"

  if (n_fail)
    warning(n_fail, " prey key(s) could not be looked up in GBIF (network or server ",
            "error). They are left unresolved for now and were not cached; run again ",
            "to retry, and see dv_taxonomy_report().", call. = FALSE)
  if (verbose) {
    tb <- table(factor(keys$match_type, levels = .DV_MATCH_TYPES))
    message("GBIF matching: ", paste(sprintf("%s=%d", names(tb), as.integer(tb)),
                                     collapse = ", "))
    if (nrow(.dv_review_rows(keys)) > 0)
      message("  -> review with dv_taxonomy_report(prep)")
  }
  keys
}

.DV_GBIF_API       <- "https://api.gbif.org/v1"
.DV_GBIF_BACKBONE  <- "d7dddbf4-2cf0-4f39-9b2a-bb099caae36c"
.DV_GBIF_CACHE_FILE <- "gbif_lineage.rds"
.DV_GBIF_RANKS     <- c("kingdom", "phylum", "class", "order", "family", "genus", "species")

# Internal: GET a GBIF URL and parse the JSON. Kept apart so tests can mock it.
# Returns the parsed list, or signals an error whose message carries the HTTP
# status when there is one.
.dv_gbif_get <- function(u) {
  con <- url(u, headers = c("User-Agent" = paste0("DietView/",
                                                  utils::packageVersion("DietView"))))
  on.exit(close(con))
  txt <- paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  jsonlite::fromJSON(txt, simplifyVector = FALSE)
}

# Internal: one GBIF request with retries. A 400/404 answer ("no such key") is
# final; anything else is retried with backoff. Returns list(value =),
# list(not_found = TRUE) or list(failed = TRUE, error =).
.dv_gbif_try <- function(u, retries = 0L) {
  res <- NULL
  for (a in 0:retries) {
    if (a > 0L) .dv_sleep(2^(a - 1L))
    res <- tryCatch(list(value = .dv_gbif_get(u)),
                    error = function(e) e, warning = function(w) w)
    if (!inherits(res, "condition")) return(res)
    if (grepl("\\b(400|404)\\b", conditionMessage(res))) return(list(not_found = TRUE))
  }
  list(failed = TRUE, error = conditionMessage(res))
}
