# Internal: the taxon label used to count richness or build categories. With
# `rank = NULL`, the finest resolved (deepest non-NA) label of each record;
# otherwise the label at that rank, records unidentified there giving NA.
.dv_taxon_label <- function(data, ranks, rank = NULL) {
  if (is.null(rank)) return(.dv_leaf_label(data, ranks))
  if (length(rank) != 1L || !rank %in% ranks)
    stop("`rank` must be one of: ", paste(ranks, collapse = ", "), call. = FALSE)
  v <- as.character(data[[rank]])
  v[v == "" | v == "NA"] <- NA
  v
}

# Internal: the finest resolved (deepest non-NA) rank label for each record.
.dv_leaf_label <- function(data, ranks) {
  lab <- rep(NA_character_, nrow(data))
  for (r in ranks) {
    v <- as.character(data[[r]])
    ok <- !is.na(v) & v != ""
    lab[ok] <- v[ok]          # later (finer) ranks overwrite -> deepest wins
  }
  lab
}

#' Describe the sampled diet dataset
#'
#' A quick overview of sample structure, computed before any figure: how many
#' stomachs and prey records each predator contributes, how many distinct prey
#' taxa were seen, and the mean number of prey records per stomach. Optionally
#' broken down by a covariate.
#'
#' By default (`rank = NULL`) a taxon is the finest resolved label of each
#' record, which mixes ranks: a stomach with *Themisto libellula* and
#' "Amphipoda" counts two taxa although *Themisto* is an amphipod, so `n_taxa`
#' overstates richness, more so as digestion advances. Give `rank` to count
#' taxa at one stated rank instead, unidentified records excluded.
#'
#' Note that a long prey-record table represents only non-empty stomachs, so
#' this function cannot report a vacuity (percent-empty) index; that must be
#' computed upstream from the full sampling frame.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param by Optional covariate column to break the summary down by.
#' @param rank Optional rank (one of `prep$ranks`, e.g. `"family"`) at which
#'   `n_taxa` is counted. `NULL` (default) uses the finest resolved label.
#' @return A data.frame with one row per predator (and per `by` level), with
#'   `n_stomachs`, `n_records`, `n_taxa`, `records_per_stomach`, and, when a
#'   weight column is declared, `total_weight`.
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
#' dv_summary(prep)
#' dv_summary(prep, by = "region")
#' head(dv_summary(prep, rank = "class"))
#' @export
dv_summary <- function(prep, by = NULL, rank = NULL) {
  stopifnot(inherits(prep, "dietview_prep"))
  d <- prep$data
  pred <- prep$spec$predator
  stom <- prep$spec$stomach
  wcol <- prep$spec$weight
  if (!is.null(by) && !by %in% names(d))
    stop("`by` column not found: ", by, call. = FALSE)

  leaf <- .dv_taxon_label(d, prep$ranks, rank)
  gcols <- c(pred, if (!is.null(by)) by)
  gkey <- do.call(paste, c(d[gcols], sep = "\r"))

  split_idx <- split(seq_len(nrow(d)), gkey)
  rows <- lapply(split_idx, function(ix) {
    g <- d[ix[1], gcols, drop = FALSE]
    out <- data.frame(g, check.names = FALSE, row.names = NULL)
    out$n_stomachs <- length(unique(as.character(d[[stom]])[ix]))
    out$n_records  <- length(ix)
    out$n_taxa     <- length(unique(stats::na.omit(leaf[ix])))
    out$records_per_stomach <- round(out$n_records / out$n_stomachs, 2)
    if (!is.null(wcol) && wcol %in% names(d))
      out$total_weight <- sum(suppressWarnings(as.numeric(d[[wcol]][ix])), na.rm = TRUE)
    out
  })
  res <- do.call(rbind, rows)
  res <- res[order(-res$n_stomachs), , drop = FALSE]
  rownames(res) <- NULL
  res
}

#' Prey accumulation (cumulative prey) curve for sample sufficiency
#'
#' Prey richness as a function of the number of stomachs examined, averaged over
#' random stomach orderings. When the curve approaches an asymptote the diet has
#' been adequately sampled; a still-rising curve warns that more stomachs would
#' reveal more prey (Ferry and Cailliet, 1996). This is a descriptive
#' sufficiency diagnostic, not a statistical test.
#'
#' By default (`rank = NULL`) a taxon is the finest resolved label of each
#' record. Labels at different ranks can name nested taxa ("Amphipoda" and
#' *Themisto libellula*), which inflates richness, and the inflation grows with
#' digestion. Give `rank` to count taxa at one stated rank, unidentified
#' records excluded.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param by Optional column giving one curve per group (e.g. the predator).
#'   `NULL` pools all records into a single curve.
#' @param rank Optional rank (one of `prep$ranks`) at which taxa are counted.
#'   `NULL` (default) uses the finest resolved label.
#' @param permutations Number of random stomach orderings to average over.
#' @param seed Optional integer for reproducibility. The seed is used for this
#'   call only: the global random stream is restored on exit.
#' @return A data.frame with (optional) group column, `n_stomachs`,
#'   `mean_richness` and `sd_richness`.
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
#' acc <- dv_prey_accumulation(prep_cod, permutations = 20, seed = 1)
#' head(acc)
#' acc_fam <- dv_prey_accumulation(prep_cod, rank = "family", permutations = 20,
#'                                 seed = 1)
#' # plot(acc$n_stomachs, acc$mean_richness, type = "b")
#' @export
dv_prey_accumulation <- function(prep, by = NULL, rank = NULL,
                                 permutations = 100, seed = NULL) {
  stopifnot(inherits(prep, "dietview_prep"))
  if (!is.null(seed)) {
    # use the seed for this call only: restore the user's random stream on exit
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
      on.exit(assign(".Random.seed", old, envir = globalenv()), add = TRUE)
    } else {
      on.exit(rm(".Random.seed", envir = globalenv()), add = TRUE)
    }
    set.seed(seed)
  }
  d <- prep$data
  stom <- prep$spec$stomach
  if (!is.null(by) && !by %in% names(d))
    stop("`by` column not found: ", by, call. = FALSE)
  leaf <- .dv_taxon_label(d, prep$ranks, rank)

  grp <- if (is.null(by)) rep("all", nrow(d)) else as.character(d[[by]])
  sid <- as.character(d[[stom]])

  one_curve <- function(ix) {
    taxa <- tapply(leaf[ix], sid[ix], function(z) unique(stats::na.omit(z)))
    S <- length(taxa)
    if (S == 0) return(NULL)
    rich <- matrix(NA_real_, permutations, S)
    for (p in seq_len(permutations)) {
      ord <- sample.int(S)
      seen <- character(0)
      for (i in seq_len(S)) {
        seen <- union(seen, taxa[[ord[i]]])
        rich[p, i] <- length(seen)
      }
    }
    data.frame(n_stomachs = seq_len(S),
               mean_richness = colMeans(rich),
               sd_richness = apply(rich, 2, stats::sd))
  }

  gl <- split(seq_len(nrow(d)), grp)
  rows <- lapply(names(gl), function(g) {
    cv <- one_curve(gl[[g]])
    if (is.null(cv)) return(NULL)
    if (!is.null(by)) cv <- cbind(stats::setNames(data.frame(g), by), cv)
    cv
  })
  res <- do.call(rbind, rows)
  rownames(res) <- NULL
  res
}

#' Frequency of occurrence per rank (the Buckland Table B1 layout)
#'
#' The classical frequency of occurrence (%FO): the proportion of
#' non-empty stomachs that contain each taxon, computed INDEPENDENTLY at each
#' taxonomic rank. Because a stomach can contain several categories, and because
#' a parent's %FO is recomputed from stomach presence rather than summed
#' from its children, these values are non-additive across ranks - which is
#' exactly why they are reported as a nested hierarchy of levels
#' (Buckland et al., 2017). This is distinct from the share of prey records
#' in [dv_build_tree()] (`pct_occ`), which is additive so that it can be drawn
#' as a sunburst: the two agree only where each stomach holds at most one record
#' of the taxon, which rarely holds at coarse ranks. Stomach identifiers must be
#' unique across predators (see [dv_validate()]).
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param rank A single rank (e.g. `"genus"`) or `NULL` for every rank stacked.
#' @param by Optional covariate to compute %FO within each level of.
#' @param include_na Keep the explicit unidentified category at each rank.
#' @return A data.frame with (optional) `by`, `rank`, `taxon`, `n_stomachs`
#'   (stomachs containing the taxon), `n_total` (stomachs in the group), and
#'   `pct_fo`.
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
#' dv_fo_table(prep_cod, rank = "class")
#' @export
dv_fo_table <- function(prep, rank = NULL, by = NULL, include_na = TRUE) {
  stopifnot(inherits(prep, "dietview_prep"))
  d <- prep$data
  stom <- prep$spec$stomach
  ranks <- if (is.null(rank)) prep$ranks else rank
  bad <- setdiff(ranks, names(d))
  if (length(bad)) stop("rank(s) not found: ", paste(bad, collapse = ", "),
                        call. = FALSE)
  if (!is.null(by) && !by %in% names(d))
    stop("`by` column not found: ", by, call. = FALSE)

  grp <- if (is.null(by)) rep("all", nrow(d)) else as.character(d[[by]])
  sid <- as.character(d[[stom]])

  out <- list()
  for (gv in unique(grp)) {
    gi <- which(grp == gv)
    n_total <- length(unique(sid[gi]))
    for (r in ranks) {
      lab <- as.character(d[[r]])[gi]
      if (include_na) lab[is.na(lab) | lab == ""] <- "NA"
      keep <- !is.na(lab)
      tab <- tapply(sid[gi][keep], lab[keep],
                    function(z) length(unique(z)))
      if (length(tab) == 0) next
      df <- data.frame(rank = r, taxon = names(tab),
                       n_stomachs = as.integer(tab),
                       n_total = n_total,
                       pct_fo = round(100 * as.integer(tab) / n_total, 2),
                       row.names = NULL)
      if (!is.null(by)) df <- cbind(stats::setNames(data.frame(gv), by), df)
      df <- df[order(-df$pct_fo), , drop = FALSE]
      out[[length(out) + 1L]] <- df
    }
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

#' Build a sampling-unit by prey-category matrix
#'
#' Reshapes the records into a unit x category matrix - the standard input to
#' multivariate diet analysis (ordination, PERMANOVA, compositional regression).
#' Rows are the sampling unit (stomachs by default, or any coarser unit such as
#' a trawl set), columns are prey categories, and cells carry the chosen
#' currency. DietView does not run those analyses; this is the handoff to the
#' tools that do.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param category Column giving the prey category. Defaults to `prey_category`
#'   (from [dv_aggregate_threshold()]) if present, otherwise the finest resolved
#'   rank label. Ignored when `rank` is given.
#' @param unit Column giving the sampling unit. Defaults to the spec's stomach.
#' @param rank Optional rank (one of `prep$ranks`, e.g. `"class"`): columns are
#'   then the taxa at that rank, plus the unidentified column (`"NA"`) when
#'   `include_na = TRUE`.
#' @param currency `"weight"` (summed mass), `"occurrence"` (record counts), or
#'   `"fo"` (presence/absence, one per unit).
#' @param include_na Keep an explicit unidentified column.
#' @return A numeric matrix with `unit` row names and category column names.
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
#' m <- dv_matrix(prep_cod, currency = "occurrence")
#' dim(m)
#' m_class <- dv_matrix(prep_cod, rank = "class", currency = "weight")
#' m_class[1:5, 1:4]
#' # vegan::decostand(m, "total"); vegan::vegdist(m, "bray")
#' @export
dv_matrix <- function(prep, category = NULL, unit = NULL, rank = NULL,
                      currency = c("weight", "occurrence", "fo"),
                      include_na = TRUE) {
  stopifnot(inherits(prep, "dietview_prep"))
  currency <- match.arg(currency)
  d <- prep$data
  if (is.null(unit)) unit <- prep$spec$stomach
  if (!unit %in% names(d)) stop("`unit` column not found: ", unit, call. = FALSE)

  if (!is.null(rank)) {
    cat_vec <- .dv_taxon_label(d, prep$ranks, rank)
  } else {
    if (is.null(category)) {
      category <- if ("prey_category" %in% names(d)) "prey_category" else NULL
    }
    cat_vec <- if (is.null(category)) .dv_leaf_label(d, prep$ranks)
               else as.character(d[[category]])
  }
  if (include_na) cat_vec[is.na(cat_vec) | cat_vec == ""] <- "NA"

  u <- as.character(d[[unit]])
  keep <- !is.na(cat_vec) & !is.na(u)
  u <- u[keep]; cat_vec <- cat_vec[keep]

  val <- switch(currency,
    weight = {
      w <- prep$spec$weight
      if (is.null(w) || !w %in% names(d))
        stop("currency = 'weight' needs a weight column in the spec.",
             call. = FALSE)
      suppressWarnings(as.numeric(d[[w]]))[keep]
    },
    occurrence = rep(1, length(u)),
    fo = rep(1, length(u))
  )
  val[is.na(val)] <- 0

  m <- tapply(val, list(u, cat_vec), sum)
  m[is.na(m)] <- 0
  if (currency == "fo") m[m > 0] <- 1
  storage.mode(m) <- "double"
  m
}
