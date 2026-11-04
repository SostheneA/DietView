#' Render a diet sunburst
#'
#' Draws the multi-rank sunburst for one set of records (or a prebuilt tree).
#' Orientation is fixed (`sort = FALSE`, fixed `rotation`), so the start angle
#' and the reading order stay the same across covariate cells. Angular
#' positions are not fixed: a taxon absent from one cell shifts every wedge
#' after it, so compare cells by color, not by angle. Records not identified at
#' a rank form a white wedge with a thin gray outline, shown as "Not identified
#' at this rank" in the hover text; no text is drawn on it (its label stays
#' `"NA"` in the data). Lineage gaps (identified material in a group
#' that has no taxon at that rank, such as `"Polychaeta (no order)"`; see
#' [dv_prepare()]) form a light gray wedge, described as such in the hover text.
#'
#' Wedges are sized from the raw values of the leaves (`branchvalues =
#' "remainder"`), and plotly sums them upward, so a parent always equals the sum
#' of its children. Because every rank has the same denominator, the angles are
#' the within-rank shares shown in the hover text.
#'
#' Three modes:
#' \itemize{
#' \item `occurrence` (default): sized by prey records (or by individuals, if
#'   the tree was built with a count column); hover shows the number and the
#'   share of all records at that rank.
#' \item `weight`: sized by weight; hover shows the weight and the weight share
#'   at that rank.
#' \item `count`: sized by the number of distinct prey items.
#' }
#'
#' @param x A `dietview_tree`, or a data.frame of records (then supply `ranks`
#'   and `weight_col`/`count_col`). Lineage gaps (a rank absent in WoRMS above
#'   an identified taxon) are labelled `"<ancestor> (no <rank>)"` by
#'   [dv_prepare()]; a data.frame passed here directly is used as is, so such
#'   gaps appear as unidentified (`"NA"`) nodes. Build the tree from a
#'   `dietview_prep`, or with [dv_tree()], to get the gap labels.
#' @param mode One of "occurrence" (default), "weight", "count".
#' @param ranks,weight_col,count_col,weight_type Passed to [dv_build_tree()]
#'   if `x` is raw (a tree carries its own `weight_type`).
#' @param colors Optional named color vector, keyed by node `id` (as from
#'   [dv_palette_tree()]) or by taxon label (as from [dv_palette()]); ids are
#'   looked up first. Default: [dv_palette_tree()] of the tree drawn, one hue
#'   per phylum with lighter tints below it. To keep colors identical across
#'   panels, build one palette from the pooled tree and pass it to each.
#' @param rotation Start angle in degrees (default 90 = top).
#' @param title,subtitle Figure titles.
#' @return A plotly sunburst.
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
#' tree <- dv_tree(prep_cod)
#' p <- dv_sunburst(tree, title = "Atlantic cod")   # mode = "occurrence"
#' p_w <- dv_sunburst(tree, mode = "weight", title = "Atlantic cod")
#' # print(p)  # opens the interactive plotly sunburst
#' @export
dv_sunburst <- function(x,
                        mode = c("occurrence", "weight", "count"),
                        ranks = NULL, weight_col = NULL, count_col = NULL,
                        colors = NULL, rotation = 90,
                        title = "", subtitle = "", weight_type = "mass") {
  mode <- match.arg(mode)

  tree <- if (inherits(x, "dietview_tree")) {
    x
  } else {
    dv_build_tree(
      x,
      ranks = ranks,
      weight_col = weight_col,
      count_col = count_col,
      weight_type = weight_type
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
      textinfo = "text",
      text = ~text,
      hovertext = ~hovertext,
      hovertemplate = "%{hovertext}<extra></extra>",
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
  if (is.null(colors)) colors <- dv_palette_tree(tree)
  # colors keyed by node id (dv_palette_tree()) win over colors keyed by label
  col <- unname(colors[tree$id]); miss <- is.na(col)
  col[miss] <- unname(colors[tree$label[miss]]); col[is.na(col)] <- "#CCCCCC"
  tree$color <- col

  # leaves carry the raw values; plotly sums them upward ("remainder")
  is_leaf <- !(tree$id %in% tree$parent)
  raw <- switch(mode, count = tree$value_item,
                occurrence = tree$value_occ, weight = tree$value_w)
  size_vals <- ifelse(is_leaf, raw, 0)

  # wedge text: unidentified ("NA") wedges stay blank; the label and the hover
  # text keep "NA" / "Not identified at this rank"
  tree$text <- .dv_wedge_text(tree$label)
  taxon <- .dv_taxon_display(tree$label)
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
    weight = {
      wl <- .dv_wlabels(attr(tree, "weight_type"))
      paste0(
        head,
        "<br><b>", wl$value, ":</b> ", formatC(tree$value_w, format = "f", digits = wl$digits),
        "<br><b>", wl$share, ":</b> ", .dv_pct_fmt(tree$pct_w)
      )
    }
  )
  list(tree = tree, size = size_vals)
}

# ---- internal: small multiples, one sunburst per covariate level ----------
# facet_col: one covariate (levels laid out in a grid), or two as
# c(inner, outer) -> one row per `outer` level, one column per `inner` level,
# matching the `cross = list(c(inner, outer))` convention of dv_build_html().
# na_strata = "drop" leaves records with a missing facet value out; "show"
# gives them an "NA" panel. A cell with fewer than `min_stomachs` stomachs
# (distinct `stomach_col`) gets its title, its stomach count and a note, no
# sunburst.
.dv_sunburst_facets <- function(records, ranks, weight_col = NULL,
                                count_col = NULL, facet_col,
                                mode = "occurrence", colors = NULL,
                                rotation = 90, title = "", na_strata = "drop",
                                stomach_col = NULL, min_stomachs = 0,
                                weight_type = "mass") {
  if (na_strata == "drop") {
    for (fc in facet_col) {
      v <- as.character(records[[fc]])
      records <- records[!(is.na(v) | v == "" | v == "NA"), , drop = FALSE]
    }
  }
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
    n_st <- if (!is.null(stomach_col)) length(unique(ce$sub[[stomach_col]])) else NA
    few <- nrow(ce$sub) > 0L && !is.na(n_st) && n_st < min_stomachs
    if (nrow(ce$sub) > 0L && !few) {
      tr <- dv_build_tree(ce$sub, ranks = ranks,
                          weight_col = weight_col, count_col = count_col,
                          weight_type = weight_type)
      pp <- .dv_sb_prep(tr, mode, colors)
      fig <- plotly::add_trace(
        fig,
        ids = pp$tree$id, labels = pp$tree$label, parents = pp$tree$parent,
        values = pp$size, type = "sunburst", branchvalues = "remainder",
        sort = FALSE, rotation = rotation, textinfo = "text", text = pp$tree$text,
        hovertext = pp$tree$hovertext, hovertemplate = "%{hovertext}<extra></extra>",
        marker = list(colors = pp$tree$color,
                      line = list(color = "#8C8C8C", width = 0.5)),
        domain = list(row = ce$row, column = ce$col)
      )
    }
    anns[[k]] <- list(
      text = paste0("<b>", ce$lab, "</b>",
                    if (nrow(ce$sub) == 0L) "<br><i>no records</i>"
                    else if (few) paste0("<br>Stomachs (n) = ", n_st,
                                         "<br><i>", .dv_few_msg(min_stomachs), "</i>")
                    else ""),
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

# Internal: the text drawn on a wedge: the label, blank for unidentified
# ("NA") nodes. Lineage gaps "(no <rank>)" keep their text.
.dv_wedge_text <- function(label) {
  label <- as.character(label)
  ifelse(!is.na(label) & label == "NA", "", label)
}

# Internal: the taxon as shown in hover text: unidentified and lineage-gap
# nodes are described rather than named.
.dv_taxon_display <- function(label) {
  label <- as.character(label)
  gap <- .dv_is_gap(label)
  gap_anc  <- sub("\\s*\\(no [a-z_]+\\)$", "", label)
  gap_rank <- sub("^.*\\(no ([a-z_]+)\\)$", "\\1", label)
  gap_txt  <- ifelse(nzchar(gap_anc),
                     paste0(gap_anc, " \u2014 no ", gap_rank, " in WoRMS (identified material)"),
                     paste0("No ", gap_rank, " in WoRMS (identified material)"))
  ifelse(label == "NA", "Not identified at this rank", ifelse(gap, gap_txt, label))
}
