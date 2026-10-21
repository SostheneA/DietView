#' Build the multi-rank tree with within-rank importance
#'
#' Aggregates a set of records into a node table spanning all ranks.
#'
#' Three quantities are carried through the tree:
#' \itemize{
#' \item `value_item`: number of distinct prey items (terminal lineages) under
#'   the node.
#' \item `value_occ`: number of prey records assigned to the node, or, when
#'   `count_col` is given, the summed number of individuals (records with an
#'   empty count then contribute 0).
#' \item `value_w`: summed weight.
#' }
#'
#' Aggregation is done at the finest rank and rolled up, so a parent's value
#' equals the sum of its children. Every record reaches every rank, under a
#' taxon or under the unidentified (`"NA"`) node, so the denominator is the same
#' at every rank: all records (or individuals) and all weight. The columns
#' `pct_occ` (share of prey records, or numerical share %N with `count_col`) and
#' `pct_w` (weight share %W) therefore sum to 100% within each rank, the
#' unidentified node included. Within each parent, unidentified nodes are placed
#' last.
#'
#' To build the tree from a prepared dataset with the columns of its spec, use
#' [dv_tree()].
#'
#' @param df A data.frame of records with the rank columns present.
#' @param ranks Ranks, coarse to fine.
#' @param weight_col Name of the weight column (or `NULL` -> zero weight).
#' @param count_col Name of a count column (or `NULL`: each record counts once).
#' @param rank_labels Optional display labels for the ranks.
#' @return A `dietview_tree` data.frame: `id, label, parent, rank, value_item,
#'   value_occ, value_w, pct_occ, pct_w`, with the attribute `currency`
#'   (`"records"`, or `"numbers"` when `count_col` is given).
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

  # reading order: rank, then parent, unidentified ("NA") last within a parent
  ord  <- order(match(tree$rank, rank_labels), tree$parent, tree$label == "NA", tree$label)
  tree <- tree[ord, , drop = FALSE]; rownames(tree) <- NULL

  class(tree) <- c("dietview_tree", "data.frame")
  attr(tree, "currency") <- if (is.null(count_col)) "records" else "numbers"
  tree
}

#' Importance table for one rank
#'
#' Convenience wrapper returning the within-rank importance for a single rank
#' (e.g. "Class"), sorted by share of prey records, the unidentified (`"NA"`)
#' row included.
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

#' Build the diet tree from a prepared dataset, using the columns in its spec
#'
#' The one way vignettes, the dashboard and the Shiny app build a tree, so that
#' one spec always gives the same numbers. By default each record counts once
#' (shares of prey records), even when the spec declares a `count` column; ask
#' for `currency = "numbers"` to count individuals instead.
#'
#' @param prep A `dietview_prep`.
#' @param currency `"records"` (each record counts once) or `"numbers"` (each
#'   record counts its `count` column; needs `count` in the spec). Records with
#'   an empty count, such as unidentified material, contribute 0 to the numbers
#'   currency, with a warning.
#' @return A `dietview_tree`, as from [dv_build_tree()].
#' @examples
#' csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
#' lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
#' dat <- read.csv(csv, na.strings = c("NA", ""))
#' lineage <- read.csv(lin, na.strings = c("NA", ""))
#' spec <- dv_spec(predator = "predator_species_common_name",
#'                 stomach = "stomach_id", prey_id = "aphia_id",
#'                 prey_name = "verified_name", weight = "prey_weight",
#'                 count = "number_of_prey")
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
#'                    verbose = FALSE)
#' tree <- dv_tree(prep)                       # shares of prey records
#' dv_rank_table(tree, "Class")
#' tree_n <- suppressWarnings(dv_tree(prep, currency = "numbers"))   # %N
#' @export
dv_tree <- function(prep, currency = c("records", "numbers")) {
  stopifnot(inherits(prep, "dietview_prep"))
  currency <- match.arg(currency)
  dv_build_tree(prep$data, prep$ranks, weight_col = prep$spec$weight,
                count_col = .dv_count_col(prep$spec, prep$data, currency))
}

# Internal: the count column to use for a currency ("records" -> NULL), with
# the checks shared by dv_tree(), dv_build_html() and run_dietview().
.dv_count_col <- function(spec, data, currency = "records") {
  if (currency != "numbers") return(NULL)
  cc <- spec$count
  if (is.null(cc)) stop("currency = 'numbers' needs `count` in the spec.", call. = FALSE)
  v <- suppressWarnings(as.numeric(data[[cc]]))
  if (any(is.na(v)))
    warning(sum(is.na(v)), " record(s) have no count and contribute 0 to the ",
            "numbers currency; unidentified material usually has no count, so ",
            "it will not appear in this view.", call. = FALSE)
  cc
}
