#' Build the multi-rank tree with within-rank importance
#'
#' Aggregates a set of records into a node table spanning all ranks.
#'
#' Three quantities are carried through the tree:
#' \itemize{
#' \item `value_item`: number of distinct terminal diet items (taxonomic leaves).
#' \item `value_occ`: occurrence count, i.e. one appearance per record (or a
#'   summed count column).
#' \item `value_w`: summed weight.
#' }
#'
#' Aggregation is done at the finest rank and rolled up, so a parent's value
#' equals the sum of its children (required for a coherent sunburst with
#' `branchvalues = "total"`). The importance columns `pct_occ` / `pct_w` are the
#' share of each node **within its own rank** (the explicit "NA" node included),
#' so every rank sums to 100%.
#'
#' @param df A data.frame of records with the rank columns present.
#' @param ranks Ranks, coarse to fine.
#' @param weight_col Name of the weight column (or `NULL` -> zero weight).
#' @param count_col Name of a count column (or `NULL` -> one occurrence per record).
#' @param rank_labels Optional display labels for the ranks.
#' @return A `dietview_tree` data.frame: `id, label, parent, rank, value_item,
#'   value_occ, value_w, pct_occ, pct_w`.
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
#' tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
#' head(tree)
#' @export
dv_build_tree <- function(df, ranks,
                          weight_col = NULL, count_col = NULL,
                          rank_labels = NULL) {
  df <- as.data.frame(df)
  if (is.null(rank_labels)) rank_labels <- .dv_titlecase(ranks)
  n <- nrow(df)
  if (n == 0) return(.dv_empty_tree())

  occ_unit <- if (is.null(count_col)) rep(1, n) else suppressWarnings(as.numeric(df[[count_col]]))
  occ_unit[is.na(occ_unit)] <- 0

  w_val <- if (is.null(weight_col)) rep(0, n) else suppressWarnings(as.numeric(df[[weight_col]]))
  w_val[is.na(w_val)] <- 0

  d <- df[, ranks, drop = FALSE]
  for (r in ranks) d[[r]] <- .dv_fill_na(d[[r]])
  d$occ_unit <- occ_unit
  d$w_val <- w_val

  leaves <- dplyr::summarise(
    dplyr::group_by(d, dplyr::across(dplyr::all_of(ranks))),
    value_item = 1,
    occ = sum(occ_unit),
    w = sum(w_val),
    .groups = "drop"
  )
  leaves <- as.data.frame(leaves)

  lvl <- lapply(seq_along(ranks), function(i) {
    cols_i <- ranks[seq_len(i)]
    g <- dplyr::summarise(
      dplyr::group_by(leaves, dplyr::across(dplyr::all_of(cols_i))),
      value_item = sum(value_item),
      value_occ = sum(occ),
      value_w = sum(w),
      .groups = "drop"
    )
    g <- as.data.frame(g)
    g$id <- do.call(paste, c(g[cols_i], sep = "|"))
    g$label <- g[[cols_i[length(cols_i)]]]
    g$parent <- if (i == 1) "" else do.call(paste, c(g[cols_i[-length(cols_i)]], sep = "|"))
    g$rank <- rank_labels[i]
    g[, c("id", "label", "parent", "rank", "value_item", "value_occ", "value_w")]
  })

  tree <- as.data.frame(dplyr::bind_rows(lvl))

  rk_occ <- tapply(tree$value_occ, tree$rank, sum)
  rk_w <- tapply(tree$value_w, tree$rank, sum)

  denom_occ <- rk_occ[tree$rank]
  denom_w <- rk_w[tree$rank]

  tree$pct_occ <- ifelse(denom_occ > 0, 100 * tree$value_occ / denom_occ, NA_real_)
  tree$pct_w <- ifelse(denom_w > 0, 100 * tree$value_w / denom_w, NA_real_)

  class(tree) <- c("dietview_tree", "data.frame")
  tree
}

#' Importance table for one rank
#'
#' Convenience wrapper returning the within-rank importance for a single rank
#' (e.g. "Class"), sorted by occurrence share, the NA row included.
#'
#' @param tree A `dietview_tree` (or a data.frame from [dv_build_tree()]).
#' @param rank Rank label to extract (e.g. "Class").
#' @return A data.frame: `label, value_item, value_occ, pct_occ, value_w, pct_w`.
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
#' tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
#' dv_rank_table(tree, "Class")
#' @export
dv_rank_table <- function(tree, rank) {
  sub <- tree[tree$rank == rank,
              c("label", "value_item", "value_occ", "pct_occ", "value_w", "pct_w")]
  sub[order(-sub$pct_occ), , drop = FALSE]
}
