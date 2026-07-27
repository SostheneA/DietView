#' Resolve prey to the WoRMS classification (exact, then optional fuzzy)
#'
#' Matches each unique prey to the World Register of Marine Species and returns
#' its lineage for the declared ranks. Matching proceeds in this order:
#' \enumerate{
#'   \item **id** - the AphiaID is already known (`prey_id`), used directly;
#'   \item **exact** - the prey name matches a WoRMS name exactly;
#'   \item **fuzzy** - (if `fuzzy = TRUE`) the closest WoRMS name is proposed;
#'   \item **unresolved** - nothing matched; all ranks stay `NA`.
#' }
#' Unaccepted names are followed to their accepted (valid) AphiaID before the
#' lineage is fetched. Every prey carries a provenance record (`match_type`,
#' `matched_name`, `aphia_used`) so fuzzy hits can be reviewed and corrected -
#' see [dv_taxonomy_report()]. Nothing is ever guessed silently: a fuzzy match is
#' flagged, and an unresolved prey keeps `NA` ranks and shows up as the explicit
#' "NA" category downstream.
#'
#' Requires the \pkg{worrms} package and internet access. Results are cached to
#' disk, so re-runs and other surveys do not requery.
#'
#' @param keys Data.frame with columns `prey_id` (AphiaID, may be NA) and
#'   `prey_name` (may be NA); one row per unique prey.
#' @param ranks Ranks to keep (default the seven flagship ranks).
#' @param cache_dir Directory for the on-disk cache. `NULL` disables caching.
#' @param fuzzy If `TRUE` (default), fall back to WoRMS fuzzy name matching when
#'   the exact name fails. Set `FALSE` for exact-only, conservative matching.
#' @param marine_only Restrict WoRMS name matching to marine taxa.
#' @param verbose Print progress.
#' @return `keys` with one column per rank plus `aphia_used`, `match_type`
#'   ("id", "exact", "fuzzy", "unresolved") and `matched_name`.
#' @examples
#' \dontrun{
#' # needs the 'worrms' package and internet access
#' keys <- data.frame(
#'   prey_id   = c(NA, NA),
#'   prey_name = c("Gadus morhua", "Homarus americanus"),
#'   stringsAsFactors = FALSE
#' )
#' dv_taxonomy_worms(keys)
#' }
#' @export
dv_taxonomy_worms <- function(keys,
                              ranks = c("kingdom", "phylum", "class", "order",
                                        "family", "genus", "species"),
                              cache_dir = tools::R_user_dir("DietView", "cache"),
                              fuzzy = TRUE,
                              marine_only = TRUE,
                              verbose = TRUE) {
  if (!requireNamespace("worrms", quietly = TRUE)) {
    stop("Install the 'worrms' package to use WoRMS taxonomy retrieval.", call. = FALSE)
  }
  keys <- as.data.frame(keys, stringsAsFactors = FALSE)
  n <- nrow(keys)
  for (r in ranks) keys[[r]] <- NA_character_
  keys$aphia_used   <- NA_integer_
  keys$match_type   <- "unresolved"
  keys$matched_name <- NA_character_

  # ---- cache ---------------------------------------------------------------
  cache_file <- NULL; cache <- list()
  if (!is.null(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, "worms_lineage.rds")
    if (file.exists(cache_file)) cache <- readRDS(cache_file)
  }

  # ---- lineage for one AphiaID (cached) ------------------------------------
  lineage_for <- function(aphia) {
    key <- paste0("id:", aphia)
    if (!is.null(cache[[key]])) return(cache[[key]])
    cl <- tryCatch(worrms::wm_classification(as.integer(aphia)), error = function(e) NULL)
    out <- stats::setNames(rep(NA_character_, length(ranks)), ranks)
    if (!is.null(cl) && nrow(cl)) {
      rk <- tolower(cl$rank)
      for (r in ranks) {
        hit <- cl$scientificname[rk == r]
        if (length(hit)) out[[r]] <- hit[1]
      }
    }
    cache[[key]] <<- out
    out
  }

  # ---- name -> record (exact, then fuzzy); follows unaccepted -> valid ------
  match_name <- function(nm) {
    key <- paste0("nm:", tolower(nm), if (fuzzy) ":f" else ":e")
    if (!is.null(cache[[key]])) return(cache[[key]])

    pick <- function(df, type) {
      if (is.null(df) || !is.data.frame(df) || !nrow(df)) return(NULL)
      # prefer an accepted record; otherwise follow valid_AphiaID
      ok <- if ("status" %in% names(df)) which(df$status == "accepted") else integer(0)
      i  <- if (length(ok)) ok[1] else 1L
      id <- if ("valid_AphiaID" %in% names(df) && !is.na(df$valid_AphiaID[i]))
        df$valid_AphiaID[i] else df$AphiaID[i]
      nmm <- if ("valid_name" %in% names(df) && !is.na(df$valid_name[i]))
        df$valid_name[i] else df$scientificname[i]
      list(aphia = as.integer(id), name = as.character(nmm), type = type)
    }
    res <- tryCatch({
      lst <- worrms::wm_records_names(
        name = nm,
        fuzzy = FALSE,
        marine_only = marine_only
      )
      df <- if (length(lst)) lst[[1]] else NULL
      pick(df, "exact")
    }, error = function(e) NULL)

    if (is.null(res) && isTRUE(fuzzy)) {
      res <- tryCatch({
        lst <- worrms::wm_records_names(
          name = nm,
          fuzzy = TRUE,
          marine_only = marine_only
        )
        df <- if (length(lst)) lst[[1]] else NULL
        pick(df, "fuzzy")
      }, error = function(e) NULL)
    }
    cache[[key]] <<- res
    res
  }

  # ---- resolve each prey ---------------------------------------------------
  for (i in seq_len(n)) {
    aphia <- suppressWarnings(as.integer(keys$prey_id[i]))
    nm    <- keys$prey_name[i]

    if (!is.na(aphia)) {
      keys$aphia_used[i]   <- aphia
      keys$match_type[i]   <- "id"
      keys$matched_name[i] <- if (!is.na(nm)) as.character(nm) else NA_character_
    } else if (!is.na(nm) && nzchar(nm)) {
      m <- match_name(nm)
      if (!is.null(m)) {
        keys$aphia_used[i]   <- m$aphia
        keys$match_type[i]   <- m$type
        keys$matched_name[i] <- m$name
      }
    }

    if (!is.na(keys$aphia_used[i])) {
      lin <- lineage_for(keys$aphia_used[i])
      for (r in ranks) keys[[r]][i] <- lin[[r]]
    }
    if (verbose && i %% 100 == 0) message(" resolved ", i, "/", n)
  }

  if (!is.null(cache_file)) saveRDS(cache, cache_file)

  if (verbose) {
    tb <- table(factor(keys$match_type,
                       levels = c("id", "exact", "fuzzy", "unresolved")))
    message(sprintf("WoRMS matching: id=%d, exact=%d, fuzzy=%d, unresolved=%d",
                    tb[["id"]], tb[["exact"]], tb[["fuzzy"]], tb[["unresolved"]]))
    if (tb[["fuzzy"]] > 0 || tb[["unresolved"]] > 0)
      message("  -> review with dv_taxonomy_report(prep)")
  }
  keys
}

#' Review fuzzy and unresolved prey matches
#'
#' Returns the prey whose taxonomy needs a human eye: fuzzy matches (WoRMS
#' proposed a close-but-not-identical name) and unresolved prey (no match). Use
#' it to audit the enrichment, then correct anything wrong by supplying a lineage
#' table (`dv_prepare(taxonomy = "table")`) or fixing the source names.
#'
#' @param prep A `dietview_prep` produced with `taxonomy = "worms"`.
#' @param which Which rows to return: "review" (fuzzy + unresolved, the default),
#'   "fuzzy", "unresolved", or "all".
#' @param file Optional CSV path to write the report to.
#' @return A data.frame with the prey name, what WoRMS matched, the match type,
#'   the AphiaID used, the number of records affected, and the resolved ranks.
#' @examples
#' \dontrun{
#' # a WoRMS-prepared object carries a taxonomy log to review
#' prep <- dv_prepare(dat, spec, taxonomy = "worms")
#' dv_taxonomy_report(prep, which = "review")
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
  keep <- switch(which,
                 review     = log$match_type %in% c("fuzzy", "unresolved"),
                 fuzzy      = log$match_type == "fuzzy",
                 unresolved = log$match_type == "unresolved",
                 all        = rep(TRUE, nrow(log)))
  out <- log[keep, , drop = FALSE]
  out <- out[order(-out$n_records), , drop = FALSE]
  if (!is.null(file)) utils::write.csv(out, file, row.names = FALSE)
  out
}
