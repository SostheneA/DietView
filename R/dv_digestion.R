#' Identification resolution: the finest rank each record reaches
#'
#' For each record, the finest rank at which the prey was identified (Kingdom,
#' Phylum, ... Species, or unresolved), summarized as shares of records and of
#' weight, overall or by any grouping columns (predator, year, region, a
#' digestion stage, a method...). It says how much of the material a figure at
#' a given rank rests on, and makes visible where identification stops: in a
#' digested stomach, or where a metabarcoding marker or reference library
#' cannot separate species. A lineage gap (`"<parent> (no <rank>)"`) is not
#' counted as an identification at that rank.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param by Optional grouping columns of `prep$data` (one or more), e.g.
#'   `prep$spec$predator` or `c("predator_common", "year")`.
#' @return A data.frame with the `by` columns, `finest_rank` (a factor, coarse
#'   to fine, then "Unresolved"), `n_records`, `p_records`, `weight` and
#'   `p_weight` (shares within each group; `p_weight` is `NA` without weight).
#' @seealso [dv_digestion_diagnostic()], the same split by digestion stage.
#' @examples
#' phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
#' dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
#' spec <- dv_spec(predator = "predator_common", stomach = "stomach_id",
#'                 prey_id = "prey_aphia_id", prey_name = "prey_name",
#'                 weight = "prey_weight_g", covariates = c("region", "year"))
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
#'                    verbose = FALSE)
#' res <- dv_resolution(prep, by = "predator_common")
#' head(res)
#' @export
dv_resolution <- function(prep, by = NULL) {
  stopifnot(inherits(prep, "dietview_prep"))
  d <- prep$data
  miss <- setdiff(by, names(d))
  if (length(miss))
    stop("`by` column not found: ", paste(miss, collapse = ", "), call. = FALSE)
  .dv_resolution_table(d, prep$ranks, prep$spec$weight, by)
}

# Internal: finest truly resolved rank per record, summarized by `by`.
.dv_resolution_table <- function(d, ranks, wcol, by = NULL) {
  if (!is.null(wcol) && !wcol %in% names(d)) wcol <- NULL
  mat <- as.data.frame(lapply(d[ranks], function(v) !is.na(v) & v != "" & !.dv_is_gap(v)))
  depth <- max.col(mat * matrix(seq_along(ranks), nrow(mat), length(ranks),
                                byrow = TRUE), ties.method = "last")
  any_hit <- rowSums(mat) > 0
  finest <- ifelse(any_hit, .dv_titlecase(ranks)[depth], "Unresolved")
  out <- d[, by, drop = FALSE]
  out$finest_rank <- factor(finest, levels = c(.dv_titlecase(ranks), "Unresolved"))
  out$w <- if (!is.null(wcol)) .dv_as_num(d[[wcol]]) else rep(0, nrow(d))
  out$w[is.na(out$w)] <- 0
  grp <- c(by, "finest_rank")
  res <- dplyr::summarise(
    dplyr::group_by(out, dplyr::across(dplyr::all_of(grp))),
    n_records = dplyr::n(), weight = sum(w), .groups = "drop")
  res <- dplyr::group_by(as.data.frame(res), dplyr::across(dplyr::all_of(by)))
  res <- dplyr::mutate(res,
                       p_records = 100 * n_records / sum(n_records),
                       p_weight  = if (sum(weight) > 0) 100 * weight / sum(weight) else NA_real_)
  as.data.frame(dplyr::ungroup(res))
}

#' Identification resolution versus digestion level
#'
#' Quantifies the identification bias linked to digestion: for each digestion
#' level, the share of records (and of weight) whose finest resolved rank is
#' Kingdom, Phylum, ... Species, or unresolved. As digestion advances, mass
#' shifts toward the coarse ranks -- this makes the bias explicit instead of
#' hiding it inside a functional grouping.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param by Optional covariate to split the diagnostic by (e.g. "period").
#' @seealso [dv_resolution()] for the same summary by any grouping, without
#'   digestion stages.
#' @return A data.frame with columns `digestion`, optional `by`, `finest_rank`,
#'   `n_records`, `p_records`, `weight`, `p_weight`.
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
#' # digestion labels in ices_diet are inferred from the older ICES format;
#' # see ?ices_diet
#' head(dv_digestion_diagnostic(prep_cod))
#' @export
dv_digestion_diagnostic <- function(prep, by = NULL) {
  stopifnot(inherits(prep, "dietview_prep"))
  spec <- prep$spec
  if (is.null(spec$digestion) || !spec$digestion %in% names(prep$data)) {
    stop("No digestion column declared in the spec. Use dv_resolution() for the ",
         "identification resolution without digestion stages.", call. = FALSE)
  }
  d <- prep$data
  if (!is.null(by) && (length(by) != 1L || !by %in% names(d)))
    stop("`by` column not found: ", paste(by, collapse = ", "), call. = FALSE)
  d$digestion <- d[[spec$digestion]]
  if (!is.null(by)) d$by <- d[[by]]
  .dv_resolution_table(d, prep$ranks, spec$weight,
                       by = if (is.null(by)) "digestion" else c("digestion", "by"))
}
