#' Write a reproducible R script for one DietView analysis
#'
#' Turns the choices behind a view (predator, currency, reporting resolution,
#' stratifying covariates and table rank) into a plain R script that rebuilds
#' it with exported DietView functions only. The Shiny application
#' ([run_dietview()]) uses it for its "Reproduce" tab, so a figure explored
#' interactively can be archived and rerun without the application.
#'
#' The script starts from the prepared data saved with
#' `saveRDS(prep, data_file)`, so it does not depend on the network or on the
#' state of WoRMS. Its header records the DietView and R versions, the date,
#' the taxonomy source (with the `worrms` version and retrieval date when the
#' lineage came from WoRMS) and the column specification.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param predator A predator to keep, or `NULL` (default) for all predators.
#' @param mode What sizes the wedges: `"occurrence"` (prey records, or
#'   individuals with `currency = "numbers"`), `"weight"` or `"count"`
#'   (distinct prey items). See [dv_sunburst()].
#' @param currency `"records"` or `"numbers"`. See [dv_tree()].
#' @param aggregation `NULL` (default: the full hierarchy, every record at
#'   every rank) or a list with `threshold` and, optionally, `scope` and
#'   `min_predators`, passed to [dv_aggregate_threshold()].
#' @param facet Up to two covariates to draw one panel per level (or per
#'   combination of levels), or `NULL`. With two, `c(inner, outer)` as in the
#'   app: `panels` is then a list over the levels of `outer`, each a list over
#'   the levels of `inner`. Missing covariate values get their own `"NA"` panel.
#' @param rank Rank for the rank table and the frequency-of-occurrence table,
#'   by column name or display label, case-insensitive. Defaults to the third
#'   rank of `prep`.
#' @param data_file File name the script reads `prep` from.
#' @param file Optional path; if given, the script is written there.
#' @return A character vector of script lines, of class `dietview_script`
#'   (invisibly when `file` is given).
#' @examples
#' prep <- dv_prepare(
#'   ices_diet[ices_diet$predator_common == "Atlantic cod", ],
#'   dv_spec(predator = "predator_common", stomach = "stomach_id",
#'           prey_id = "prey_aphia_id", prey_name = "prey_name",
#'           weight = "prey_weight_g", covariates = "quarter"),
#'   taxonomy = "table", lineage = ices_lineage, verbose = FALSE)
#' s <- dv_script(prep, mode = "weight",
#'                aggregation = list(threshold = 10, scope = "pooled"))
#' s
#' @export
dv_script <- function(prep, predator = NULL,
                      mode = c("occurrence", "weight", "count"),
                      currency = c("records", "numbers"),
                      aggregation = NULL, facet = NULL, rank = NULL,
                      data_file = "dietview_prep.rds", file = NULL) {
  stopifnot(inherits(prep, "dietview_prep"))
  mode <- match.arg(mode)
  currency <- match.arg(currency)
  spec <- prep$spec
  if (is.null(rank)) rank <- prep$ranks[min(3L, length(prep$ranks))]
  rank <- .dv_match_rank(rank, prep$ranks)
  facet <- facet[!is.na(facet) & nzchar(facet)]
  if (length(facet) > 2L) stop("`facet` takes at most two covariates.", call. = FALSE)
  bad <- setdiff(facet, names(prep$data))
  if (length(bad)) stop("Unknown covariate(s): ", paste(bad, collapse = ", "), call. = FALSE)
  if (!is.null(aggregation)) {
    if (is.null(aggregation$threshold))
      stop("`aggregation` needs a `threshold`.", call. = FALSE)
    aggregation$scope <- match.arg(aggregation$scope %||% "pooled",
                                   c("pooled", "per_predator"))
    aggregation$min_predators <- as.integer(aggregation$min_predators %||% 1L)
  }
  dq <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = "")

  spec_args <- spec[c("predator", "predator_latin", "stomach", "prey_id", "prey_name",
                      "weight", "count", "digestion", "covariates", "ranks")]
  spec_args <- spec_args[!vapply(spec_args, function(v) is.null(v) || !length(v), logical(1))]
  spec_lines <- paste0("#   ", names(spec_args), " = ",
                       vapply(spec_args, dq, character(1)))

  tax <- prep$taxonomy_source %||% "unknown"
  log <- prep$taxonomy_log
  tax_note <- if (!is.null(log))
    sprintf("# Taxonomy: WoRMS via worrms %s, retrieved %s",
            attr(log, "worrms_version") %||% "?", attr(log, "retrieved") %||% "?")
  else sprintf("# Taxonomy source: %s", tax)

  cnt <- if (currency == "numbers") dq(spec$count) else "NULL"
  wt  <- if (!is.null(spec$weight)) dq(spec$weight) else "NULL"
  agg_txt <- if (is.null(aggregation)) "full hierarchy (no aggregation)" else
    sprintf("threshold %s stomachs, scope = %s, min_predators = %d",
            format(aggregation$threshold), aggregation$scope, aggregation$min_predators)

  L <- c(
    "## DietView analysis script",
    sprintf("## Generated %s with DietView %s and %s.",
            format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
            as.character(utils::packageVersion("DietView")), R.version.string),
    sprintf("## Predator: %s | wedges: %s | currency: %s",
            predator %||% "all predators", mode, currency),
    sprintf("## Reporting resolution: %s", agg_txt),
    tax_note,
    "# Column specification of the prepared data:",
    spec_lines,
    "",
    "library(DietView)",
    "",
    sprintf("## 1. Prepared data (save it from R with saveRDS(prep, %s))", dq(data_file)),
    sprintf("prep <- readRDS(%s)", dq(data_file)),
    "spec <- prep$spec",
    "prep"
  )
  if (!is.null(aggregation)) {
    L <- c(L, "",
      "## 2. Reporting resolution: rare prey merged up their lineage",
      "## (applied before selecting a predator, so pooled counts use all predators)",
      sprintf("prep <- dv_aggregate_threshold(prep, threshold = %s, scope = %s, min_predators = %d)",
              format(aggregation$threshold), dq(aggregation$scope), aggregation$min_predators),
      "attr(prep, \"aggregation\")")
  }
  L <- c(L, "",
    "## 3. Colors: one hue per phylum, from the pooled tree of all predators, so a",
    "## taxon keeps its color in every view (unidentified material is white)",
    "fill_na <- function(x) { x <- as.character(x); x[is.na(x) | x == \"\"] <- \"NA\"; x }",
    "pal <- dv_palette_tree(dv_build_tree(prep$data, prep$ranks))")
  if (!is.null(predator)) {
    L <- c(L, "",
      "## 4. Predator",
      sprintf("prep$data <- prep$data[which(as.character(prep$data[[spec$predator]]) == %s), ]",
              dq(predator)))
  }
  L <- c(L, "",
    "## 5. Multi-rank tree and sunburst",
    sprintf("tree <- dv_build_tree(prep$data, prep$ranks, weight_col = %s, count_col = %s)",
            wt, cnt),
    sprintf("dv_sunburst(tree, mode = %s, colors = pal, title = %s)",
            dq(mode), dq(predator %||% "All predators")))
  if (length(facet)) {
    L <- c(L, "",
      "## 6. One panel per covariate level (missing values get their own \"NA\" panel)",
      "panel <- function(d, title)",
      sprintf("  dv_sunburst(d, mode = %s, ranks = prep$ranks, weight_col = %s,", dq(mode), wt),
      sprintf("              count_col = %s, colors = pal, title = title)", cnt))
    if (length(facet) == 1L) {
      L <- c(L,
        sprintf("cells <- split(prep$data, fill_na(prep$data[[%s]]))", dq(facet)),
        sprintf("panels <- lapply(names(cells), function(l) panel(cells[[l]], paste0(%s, l)))",
                dq(paste0(facet, ": "))),
        "names(panels) <- names(cells)",
        "# panels[[1]]   # print any panel; htmlwidgets::saveWidget() archives it")
    } else {
      L <- c(L,
        sprintf("## rows: levels of %s; columns: levels of %s (the grid of the app)",
                facet[2], facet[1]),
        sprintf("rows <- split(prep$data, fill_na(prep$data[[%s]]))", dq(facet[2])),
        "panels <- lapply(names(rows), function(o) {",
        sprintf("  cells <- split(rows[[o]], fill_na(rows[[o]][[%s]]))", dq(facet[1])),
        "  stats::setNames(lapply(names(cells), function(i)",
        sprintf("    panel(cells[[i]], paste0(%s, o, %s, i))),",
                dq(paste0(facet[2], ": ")), dq(paste0(" | ", facet[1], ": "))),
        "    names(cells))",
        "})",
        "names(panels) <- names(rows)",
        "# panels[[1]][[1]]   # print any panel; htmlwidgets::saveWidget() archives it")
    }
  }
  L <- c(L, "",
    "## 7. Tables behind the figure",
    sprintf("dv_rank_table(tree, %s)", dq(.dv_titlecase(rank))),
    sprintf("dv_fo_table(prep, rank = %s)", dq(rank)))
  if (!is.null(spec$digestion) && spec$digestion %in% names(prep$data)) {
    L <- c(L, "dv_digestion_diagnostic(prep)")
  }
  L <- c(L, "", "sessionInfo()")

  class(L) <- "dietview_script"
  if (!is.null(file)) {
    writeLines(L, file, useBytes = TRUE)
    return(invisible(L))
  }
  L
}

#' @export
print.dietview_script <- function(x, ...) {
  cat(unclass(x), sep = "\n")
  invisible(x)
}
