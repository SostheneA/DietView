#' Render a diet sunburst
#'
#' Draws the multi-rank sunburst for one set of records (or a prebuilt tree).
#' Orientation is fixed (`sort = FALSE`, fixed `rotation`), so the start angle
#' and the reading order stay the same across covariate cells. Angular
#' positions are not fixed: a taxon absent from one cell shifts every wedge
#' after it, so compare cells by color, not by angle. Records not identified at
#' a rank form a white wedge with a thin gray outline, shown as "Not identified
#' at this rank" in the hover text.
#'
#' Wedges are sized from the raw values of the leaves (`branchvalues =
#' "remainder"`), and plotly sums them upward, so a parent always equals the sum
#' of its children. Because every rank has the same denominator, the angles are
#' the within-rank shares shown in the hover text.
#'
#' Three modes:
#' \itemize{
#' \item `count`: sized by the number of distinct prey items.
#' \item `occurrence`: sized by prey records (or by individuals, if the tree
#'   was built with a count column); hover shows the number and the share of all
#'   records at that rank. The value `"occurrence"` is kept for backward
#'   compatibility.
#' \item `weight`: sized by weight; hover shows the weight and the weight share
#'   at that rank.
#' }
#'
#' @param x A `dietview_tree`, or a data.frame of records (then supply `ranks`
#'   and `weight_col`/`count_col`).
#' @param mode One of "count", "occurrence", "weight".
#' @param ranks,weight_col,count_col Passed to [dv_build_tree()] if `x` is raw.
#' @param colors Optional named color vector, keyed by node `id` (as from
#'   [dv_palette_tree()]) or by taxon label (as from [dv_palette()]); ids are
#'   looked up first. Default from [dv_palette()].
#' @param rotation Start angle in degrees (default 90 = top).
#' @param title,subtitle Figure titles.
#' @return A plotly sunburst.
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
#' p <- dv_sunburst(tree, mode = "occurrence", title = "All predators")
#' # print(p)  # opens the interactive plotly sunburst
#' @export
dv_sunburst <- function(x,
                        mode = c("count", "occurrence", "weight"),
                        ranks = NULL, weight_col = NULL, count_col = NULL,
                        colors = NULL, rotation = 90,
                        title = "", subtitle = "") {
  mode <- match.arg(mode)

  tree <- if (inherits(x, "dietview_tree")) {
    x
  } else {
    dv_build_tree(
      x,
      ranks = ranks,
      weight_col = weight_col,
      count_col = count_col
    )
  }

  pp <- .dv_sb_prep(tree, mode, colors)

  plotly::layout(
    plotly::plot_ly(
      data = pp$tree,
      ids = ~id,
      labels = ~label,
      parents = ~parent,
      values = pp$size,
      type = "sunburst",
      branchvalues = "remainder",
      sort = FALSE,
      rotation = rotation,
      textinfo = "label",
      text = ~hovertext,
      hovertemplate = "%{text}<extra></extra>",
      marker = list(colors = ~color, line = list(color = "#8C8C8C", width = 0.5))
    ),
    title = list(
      text = paste0(
        title,
        if (nzchar(subtitle)) paste0("<br><sup>", subtitle, "</sup>") else ""
      ),
      font = list(size = 14)
    ),
    margin = list(t = 60)
  )
}

# ---- internal: color, size, and hover fields for one tree ----------------
.dv_sb_prep <- function(tree, mode, colors = NULL) {
  if (is.null(colors)) colors <- dv_palette(tree$label)
  # colors keyed by node id (dv_palette_tree()) win over colors keyed by label
  col <- unname(colors[tree$id]); miss <- is.na(col)
  col[miss] <- unname(colors[tree$label[miss]]); col[is.na(col)] <- "#CCCCCC"
  tree$color <- col

  # leaves carry the raw values; plotly sums them upward ("remainder")
  is_leaf <- !(tree$id %in% tree$parent)
  raw <- switch(mode, count = tree$value_item,
                occurrence = tree$value_occ, weight = tree$value_w)
  size_vals <- ifelse(is_leaf, raw, 0)

  taxon <- ifelse(tree$label == "NA", "Not identified at this rank", tree$label)
  head  <- paste0("<b>Rank:</b> ", tree$rank, "<br><b>Taxon:</b> ", taxon)
  tree$hovertext <- switch(
    mode,
    count = paste0(head, "<br><b>Distinct prey items:</b> ", tree$value_item),
    occurrence = if (identical(attr(tree, "currency"), "numbers")) paste0(
      head,
      "<br><b>Individuals:</b> ", tree$value_occ,
      "<br><b>Numerical share at this rank (%N):</b> ", .dv_pct_fmt(tree$pct_occ)
    ) else paste0(
      head,
      "<br><b>Prey records:</b> ", tree$value_occ,
      "<br><b>Share of all records at this rank:</b> ", .dv_pct_fmt(tree$pct_occ)
    ),
    weight = paste0(
      head,
      "<br><b>Weight:</b> ", formatC(tree$value_w, format = "f", digits = 1),
      "<br><b>Weight share at this rank:</b> ", .dv_pct_fmt(tree$pct_w)
    )
  )
  list(tree = tree, size = size_vals)
}

# ---- internal: small multiples, one sunburst per covariate level ----------
# facet_col: one covariate (levels laid out in a grid), or two as
# c(inner, outer) -> one row per `outer` level, one column per `inner` level,
# matching the `cross = list(c(inner, outer))` convention of dv_build_html().
.dv_sunburst_facets <- function(records, ranks, weight_col = NULL,
                                count_col = NULL, facet_col,
                                mode = "occurrence", colors = NULL,
                                rotation = 90, title = "") {
  crossed <- length(facet_col) >= 2L
  if (crossed) {
    inner <- facet_col[1]; outer <- facet_col[2]
    ol <- sort(unique(.dv_fill_na(as.character(records[[outer]]))))
    il <- sort(unique(.dv_fill_na(as.character(records[[inner]]))))
    cells <- list()
    for (r in seq_along(ol)) for (c in seq_along(il)) {
      cells[[length(cells) + 1L]] <- list(
        sub = records[.dv_fill_na(as.character(records[[outer]])) == ol[r] &
                      .dv_fill_na(as.character(records[[inner]])) == il[c], , drop = FALSE],
        lab = paste0(outer, ": ", ol[r], " | ", inner, ": ", il[c]),
        row = r - 1L, col = c - 1L)
    }
    n_row <- length(ol); n_col <- length(il)
  } else {
    lv   <- .dv_fill_na(as.character(records[[facet_col]]))
    levs <- sort(unique(lv))
    n_col <- ceiling(sqrt(length(levs)))
    n_row <- ceiling(length(levs) / n_col)
    cells <- lapply(seq_along(levs), function(i) list(
      sub = records[lv == levs[i], , drop = FALSE],
      lab = paste0(facet_col, ": ", levs[i]),
      row = (i - 1L) %/% n_col, col = (i - 1L) %% n_col))
  }

  fig  <- plotly::plot_ly()
  anns <- list()
  for (k in seq_along(cells)) {
    ce <- cells[[k]]
    if (nrow(ce$sub) > 0L) {
      tr <- dv_build_tree(ce$sub, ranks = ranks,
                          weight_col = weight_col, count_col = count_col)
      pp <- .dv_sb_prep(tr, mode, colors)
      fig <- plotly::add_trace(
        fig,
        ids = pp$tree$id, labels = pp$tree$label, parents = pp$tree$parent,
        values = pp$size, type = "sunburst", branchvalues = "remainder",
        sort = FALSE, rotation = rotation, textinfo = "label",
        text = pp$tree$hovertext, hovertemplate = "%{text}<extra></extra>",
        marker = list(colors = pp$tree$color,
                      line = list(color = "#8C8C8C", width = 0.5)),
        domain = list(row = ce$row, column = ce$col)
      )
    }
    anns[[k]] <- list(
      text = paste0("<b>", ce$lab, "</b>",
                    if (nrow(ce$sub) == 0L) "<br><i>no records</i>" else ""),
      x = (ce$col + 0.5) / n_col, y = 1 - ce$row / n_row,
      xref = "paper", yref = "paper",
      xanchor = "center", yanchor = "top",
      showarrow = FALSE, font = list(size = 11)
    )
  }
  plotly::layout(
    fig,
    grid = list(rows = n_row, columns = n_col, pattern = "independent"),
    title = list(text = title, font = list(size = 14)),
    annotations = anns,
    margin = list(t = 70)
  )
}
