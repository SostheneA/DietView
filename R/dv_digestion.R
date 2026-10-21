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
    stop("No digestion column declared in the spec.", call. = FALSE)
  }
  d <- prep$data
  ranks <- prep$ranks
  wcol <- spec$weight

  # finest resolved rank per record
  mat <- as.data.frame(lapply(d[ranks], function(v) !is.na(v) & v != ""))
  depth <- max.col(mat * matrix(seq_along(ranks), nrow(mat), length(ranks),
                                byrow = TRUE), ties.method = "last")
  any_hit <- rowSums(mat) > 0
  finest <- ifelse(any_hit, .dv_titlecase(ranks)[depth], "Unresolved")

  out <- data.frame(
    digestion = d[[spec$digestion]],
    finest_rank = factor(finest, levels = c(.dv_titlecase(ranks), "Unresolved")),
    w = if (!is.null(wcol)) suppressWarnings(as.numeric(d[[wcol]])) else 0,
    stringsAsFactors = FALSE
  )
  if (!is.null(by)) out$by <- d[[by]]
  out$w[is.na(out$w)] <- 0

  grp <- if (!is.null(by)) c("digestion", "by", "finest_rank") else c("digestion", "finest_rank")
  res <- dplyr::summarise(
    dplyr::group_by(out, dplyr::across(dplyr::all_of(grp))),
    n_records = dplyr::n(), weight = sum(w), .groups = "drop"
  )
  res <- as.data.frame(res)

  denom_grp <- setdiff(grp, "finest_rank")
  res <- dplyr::group_by(res, dplyr::across(dplyr::all_of(denom_grp)))
  res <- dplyr::mutate(res,
                       p_records = 100 * n_records / sum(n_records),
                       p_weight  = if (sum(weight) > 0) 100 * weight / sum(weight) else NA_real_)
  as.data.frame(dplyr::ungroup(res))
}
