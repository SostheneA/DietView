#' Aggregate rare prey upward to a stomach-frequency threshold
#'
#' Collapses prey that occur in fewer than `threshold` stomachs into their
#' parent taxon, walking up the taxonomic hierarchy until every retained
#' category meets the threshold. This is a threshold-based aggregation in the
#' spirit of taxonomic sufficiency (Bevilacqua et al., 2012; Pombo et al.,
#' 2013), for when a diet description must be stable to the choice of
#' reporting rank: finer, rarely seen taxa are merged upward rather than
#' dropped.
#'
#' Each record first settles at the deepest ancestor whose whole subtree is
#' found in at least `threshold` stomachs. The category reported for a node is
#' its residual, the records that settled there and not deeper, so a residual
#' that itself falls below the threshold is moved up one more rank, and so on
#' until every reported category reaches `threshold` stomachs (and
#' `min_predators` predators). A residual whose node also has retained
#' descendants is labelled `"<taxon> (other)"` in `prey_category`, for example
#' `"Malacostraca (other)"` for malacostracans other than the retained orders.
#'
#' Three architectures are expressed through two arguments:
#' \itemize{
#'   \item \strong{Pooled} (default): `scope = "pooled"`, `min_predators = 1`.
#'     Counts are taken across the whole dataset.
#'   \item \strong{Pooled cross-predator}: `scope = "pooled"`,
#'     `min_predators = 2`. A category is retained only if its subtree also
#'     spans at least `min_predators` predator species.
#'   \item \strong{Per-predator}: `scope = "per_predator"`. Counts are taken
#'     within each predator separately, so each predator gets its own tree.
#' }
#'
#' The taxonomy columns of the returned object are pruned: for every record,
#' ranks finer than the settled rank are set to `NA`, so the explicit-NA
#' machinery of [dv_build_tree()] shows the merge, and the sunburst has no
#' leaf rarer than `threshold` stomachs (apart from the records that were
#' unidentified at every rank to begin with, and the `other_label` group). A convenience column `prey_category`
#' (the settled label) and `prey_rank` (the rank it settled at) are added, so
#' the result can also feed a flat set x category matrix.
#'
#' @param prep A `dietview_prep` object from [dv_prepare()].
#' @param threshold Minimum number of stomachs a category must occur in to be
#'   retained at a given rank.
#' @param scope `"pooled"` (counts across the dataset) or `"per_predator"`
#'   (counts within each predator).
#' @param min_predators Minimum number of distinct predators a category's
#'   subtree must span to be retained. Ignored (forced to 1) when
#'   `scope = "per_predator"`. Set to 2 for the cross-predator variant.
#' @param other_label Label for records that do not reach the threshold even at
#'   the coarsest rank; defaults to `"other (below threshold)"`.
#' @return A `dietview_prep` with pruned taxonomy columns and the added
#'   `prey_category` / `prey_rank` columns. Feed it to [dv_build_tree()] exactly
#'   as you would the output of [dv_prepare()].
#' @seealso [dv_threshold_sweep()] to run this across many thresholds.
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
#' # Atlantic cod only, for speed
#' cod <- dat[dat$predator_common == "Atlantic cod", ]
#' prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
#'                        verbose = FALSE)
#'
#' # keep only taxa seen in >= 10 stomachs; rarer prey merge upward
#' agg <- dv_aggregate_threshold(prep_cod, threshold = 10)
#' table(agg$data$prey_rank, useNA = "ifany")
#'
#' # the pruned prep drops straight into the usual pipeline
#' tree <- dv_build_tree(agg$data, agg$ranks, weight_col = spec$weight)
#' head(dv_rank_table(tree, "Class"))
#' @export
dv_aggregate_threshold <- function(prep, threshold,
                                   scope = c("pooled", "per_predator"),
                                   min_predators = 1L,
                                   other_label = NULL) {
  stopifnot(inherits(prep, "dietview_prep"))
  scope <- match.arg(scope)
  if (!is.numeric(threshold) || length(threshold) != 1L || threshold < 1)
    stop("`threshold` must be a single number >= 1.", call. = FALSE)

  ranks <- prep$ranks
  d <- prep$data
  K <- length(ranks)
  n <- nrow(d)
  stom <- prep$spec$stomach
  pred <- prep$spec$predator
  if (is.null(stom) || !stom %in% names(d))
    stop("The spec's stomach column is required for threshold aggregation.",
         call. = FALSE)

  if (is.null(other_label)) other_label <- "other (below threshold)"
  mp <- if (scope == "per_predator") 1L else as.integer(min_predators)

  sv <- as.character(d[[stom]])
  pv <- if (!is.null(pred) && pred %in% names(d)) as.character(d[[pred]]) else rep("", n)

  # cumulative node key at each rank; NA beyond the resolved (contiguous) depth
  key <- matrix(NA_character_, n, K)
  prev_ok <- rep(TRUE, n)
  acc <- rep("", n)
  for (j in seq_len(K)) {
    lab <- as.character(d[[ranks[j]]])
    ok  <- prev_ok & !is.na(lab) & lab != ""
    acc_j <- ifelse(ok, paste(acc, lab, sep = ">"), NA_character_)
    key[, j] <- acc_j
    acc <- ifelse(ok, acc_j, acc)
    prev_ok <- ok
  }
  depth <- rowSums(!is.na(key))   # 0 = nothing resolved

  # deepest rank whose subtree meets the threshold (and predator spread)
  settled <- rep(NA_integer_, n)
  for (j in seq_len(K)) {
    k <- key[, j]
    idx <- !is.na(k)
    if (!any(idx)) next
    gk <- if (scope == "per_predator") paste(pv, k, sep = "@@") else k
    sc <- tapply(sv[idx], gk[idx], function(z) length(unique(z)))
    pc <- tapply(pv[idx], gk[idx], function(z) length(unique(z)))
    s_cnt <- as.integer(sc[gk[idx]])
    p_cnt <- as.integer(pc[gk[idx]])
    ok <- s_cnt >= threshold & p_cnt >= mp
    hit <- which(idx)[ok]
    settled[hit] <- j            # deepest wins (j increases)
  }

  # the reported category is the residual at the settled node; it must itself
  # reach the threshold, otherwise its records move up one rank (repeat)
  repeat {
    rows <- which(!is.na(settled))
    if (!length(rows)) break
    node <- key[cbind(rows, settled[rows])]
    gk   <- if (scope == "per_predator") paste(pv[rows], node, sep = "@@") else node
    s_cnt <- tapply(sv[rows], gk, function(z) length(unique(z)))
    p_cnt <- tapply(pv[rows], gk, function(z) length(unique(z)))
    bad   <- names(s_cnt)[s_cnt < threshold | p_cnt < mp]
    hit   <- rows[gk %in% bad]
    if (!length(hit)) break
    up <- hit[settled[hit] > 1L]
    settled[up] <- settled[up] - 1L
    settled[setdiff(hit, up)] <- NA_integer_     # failed at the coarsest rank -> "other"
    if (!length(up)) break
  }

  # records that never meet the threshold -> coarsest rank, flagged "other"
  need_other <- is.na(settled) & depth >= 1L
  settled[need_other] <- 1L

  # prune taxonomy: ranks finer than settled -> NA
  out <- d
  for (j in seq_len(K)) {
    keep <- !is.na(settled) & j <= settled
    v <- as.character(out[[ranks[j]]])
    v[!keep] <- NA
    out[[ranks[j]]] <- v
  }
  if (any(need_other)) {
    v <- as.character(out[[ranks[1]]]); v[need_other] <- other_label
    out[[ranks[1]]] <- v
  }

  # settled label + rank for a flat set x category matrix
  # a residual whose node also has retained (deeper) descendants is "(other)"
  lab_settled <- rep(NA_character_, n)
  for (j in seq_len(K)) {
    sel <- !is.na(settled) & settled == j
    if (!any(sel)) next
    lab <- as.character(d[[ranks[j]]])[sel]
    deeper <- !is.na(settled) & settled > j
    has_desc <- key[sel, j] %in% key[deeper, j]
    lab[has_desc] <- paste0(lab[has_desc], " (other)")
    lab_settled[sel] <- lab
  }
  lab_settled[need_other] <- other_label
  out$prey_category <- lab_settled
  out$prey_rank <- ifelse(is.na(settled), NA_character_, ranks[pmax(settled, 1L)])

  res <- prep
  res$data <- out
  attr(res, "aggregation") <- list(threshold = threshold, scope = scope,
                                    min_predators = mp, other_label = other_label,
                                    n_categories = length(unique(stats::na.omit(lab_settled))))
  res
}

#' Count diet categories across a sweep of thresholds
#'
#' Runs [dv_aggregate_threshold()] over a vector of thresholds and reports how
#' many prey categories each one yields. This reproduces the "resolutions"
#' bookkeeping of resolution-robust diet analysis (e.g. thresholds 10-1000 by
#' 10 give 100 resolutions; a per-predator sweep of 5-250 by 5 gives 50), so
#' downstream summaries can be reported as a mean +/- SD across resolutions.
#'
#' This function only counts categories; it does not compute diet indices or
#' run any statistical test. Those belong in the analysis that consumes the
#' per-resolution `prey_category` column, not in DietView.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param thresholds A numeric vector of thresholds, e.g. `seq(10, 1000, 10)`.
#' @param scope,min_predators Passed to [dv_aggregate_threshold()].
#' @return A data.frame with `threshold`, `n_categories` (number of prey
#'   categories) and `pct_coarser` (percentage of all records whose category is
#'   coarser than the finest rank, the unidentified and `other` records
#'   included).
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
#' # Atlantic cod only, for speed
#' cod <- dat[dat$predator_common == "Atlantic cod", ]
#' prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
#'                        verbose = FALSE)
#' dv_threshold_sweep(prep_cod, thresholds = c(2, 5, 10, 20))
#' @export
dv_threshold_sweep <- function(prep, thresholds,
                               scope = c("pooled", "per_predator"),
                               min_predators = 1L) {
  scope <- match.arg(scope)
  ranks <- prep$ranks
  rows <- lapply(thresholds, function(x) {
    a <- dv_aggregate_threshold(prep, x, scope = scope, min_predators = min_predators)
    pr <- a$data$prey_rank
    data.frame(threshold = x,
               n_categories = attr(a, "aggregation")$n_categories,
               pct_coarser = round(100 * mean(is.na(pr) | pr != ranks[length(ranks)]), 2))
  })
  do.call(rbind, rows)
}
