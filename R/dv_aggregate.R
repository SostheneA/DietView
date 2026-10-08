#' Aggregate rare prey upward to a stomach-frequency threshold
#'
#' Collapses prey that occur in fewer than `threshold` stomachs into their
#' parent taxon, walking up the taxonomic hierarchy until every retained
#' category meets the threshold. This is the threshold-based, resolution-robust
#' aggregation used when a diet description must be stable to the choice of
#' reporting rank (Buckland et al., 2017; Pombo et al., 2013; Bevilacqua et
#' al., 2012): each record settles at the deepest ancestor whose subtree is
#' sampled widely enough, and finer, rarely seen taxa are merged upward rather
#' than dropped.
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
#' leaf rarer than `threshold` stomachs. A convenience column `prey_category`
#' (the settled label) and `prey_rank` (the rank it settled at) are added, so
#' the result can also feed a flat set x category matrix.
#'
#' @param prep A `dietview_prep` object from [dv_prepare()].
#' @param threshold Minimum number of stomachs a category must occur in to be
#'   retained at a given rank (the paper's `x`).
#' @param scope `"pooled"` (counts across the dataset) or `"per_predator"`
#'   (counts within each predator).
#' @param min_predators Minimum number of distinct predators a category's
#'   subtree must span to be retained. Ignored (forced to 1) when
#'   `scope = "per_predator"`. Set to 2 for the cross-predator variant.
#' @param other_label Label for records that do not reach the threshold even at
#'   the coarsest rank; defaults to `paste0("other ", <coarsest rank>)`.
#' @return A `dietview_prep` with pruned taxonomy columns and the added
#'   `prey_category` / `prey_rank` columns. Feed it to [dv_build_tree()] exactly
#'   as you would the output of [dv_prepare()].
#' @seealso [dv_threshold_sweep()] to run this across many thresholds.
#' @examples
#' csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
#' lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
#' dat <- read.csv(csv, na.strings = c("NA", ""))
#' lineage <- read.csv(lin, na.strings = c("NA", ""))
#' spec <- dv_spec(predator = "predator_species_common_name",
#'                 stomach = "stomach_id", prey_id = "aphia_id",
#'                 prey_name = "verified_name", weight = "prey_weight")
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
#'                    verbose = FALSE)
#'
#' # retain only taxa seen in >= 3 stomachs; rarer prey merge upward
#' agg <- dv_aggregate_threshold(prep, threshold = 3)
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

  if (is.null(other_label)) other_label <- paste0("other ", ranks[1])
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
  lab_settled <- rep(NA_character_, n)
  for (j in seq_len(K)) {
    sel <- !is.na(settled) & settled == j
    lab_settled[sel] <- as.character(d[[ranks[j]]])[sel]
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
#' @return A data.frame with `threshold`, `n_categories` and `n_records`.
#' @examples
#' csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
#' lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
#' dat <- read.csv(csv, na.strings = c("NA", ""))
#' lineage <- read.csv(lin, na.strings = c("NA", ""))
#' spec <- dv_spec(predator = "predator_species_common_name",
#'                 stomach = "stomach_id", prey_id = "aphia_id",
#'                 prey_name = "verified_name", weight = "prey_weight")
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
#'                    verbose = FALSE)
#' dv_threshold_sweep(prep, thresholds = c(2, 3, 5, 8))
#' @export
dv_threshold_sweep <- function(prep, thresholds,
                               scope = c("pooled", "per_predator"),
                               min_predators = 1L) {
  scope <- match.arg(scope)
  rows <- lapply(thresholds, function(x) {
    a <- dv_aggregate_threshold(prep, x, scope = scope, min_predators = min_predators)
    data.frame(threshold = x,
               n_categories = attr(a, "aggregation")$n_categories,
               n_records = nrow(a$data))
  })
  do.call(rbind, rows)
}
