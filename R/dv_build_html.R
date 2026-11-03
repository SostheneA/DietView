#' Build a self-contained HTML diet dashboard
#'
#' Builds a dashboard from any prepared dataset: a searchable,
#' sortable landing grid of predator cards (stomach counts, length range, ID
#' photo, description) plus one tab per predator. Each tab shows the diet in
#' bands of sunbursts (by default prey records as % of all records and weight
#' as % of total weight; distinct prey items on request); each band repeats the
#' same structure:
#' an aggregated sunburst, one row of sunbursts per declared covariate, and
#' optionally crossed rows (e.g. length bins split by period). Records whose
#' covariate is `NA` are left out of that covariate's rows by default
#' (`na_strata = "drop"`); `na_strata = "show"` gives them an "NA" panel, as
#' in [run_dietview()].
#'
#' The file stays small and opens fast: plotly.js is included once, the data of
#' every sunburst (node ids, labels, parents, values and colors) is stored once
#' as JSON, and the sunbursts of a tab are drawn the first time the tab is
#' opened. The file works offline. Colors come from [dv_palette_tree()] built on
#' the pooled tree of the whole dataset, so a taxon has the same color in every
#' panel. The cards can be opened with the mouse or with the keyboard (Tab,
#' then Enter or Space).
#'
#' By default the record band counts prey records, even when the spec declares
#' a `count` column; set `currency = "numbers"` to count individuals (%N)
#' instead. The default call touches neither the network nor the working
#' directory: photos are fetched only with `photo_source = "inaturalist"` or
#' `"wikipedia"`, and downloads go to a folder in [tempdir()] unless
#' `image_dir` says otherwise. Each card shows the photo's author and license,
#' linked to the photo's page; see [dv_species_card_assets()].
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param output Output HTML path (required).
#' @param strata Covariates to stratify each band by (default: all declared).
#' @param cross List of `c(inner, outer)` covariate pairs to also show crossed
#'   (for each level of `outer`, a row of `inner` levels). E.g.
#'   `list(c("size_bin", "period"))`.
#' @param bands Which bands to draw and in which order, any of
#'   `"occurrence"` (prey records, or individuals with
#'   `currency = "numbers"`), `"weight"` and `"count"` (distinct prey
#'   items). Default: occurrence and weight.
#' @param currency `"records"` (default: each record counts once) or
#'   `"numbers"` (each record counts its `count` column; needs `count` in the
#'   spec). See [dv_tree()].
#' @param length_col Optional numeric length column, to show length ranges on cards.
#' @param species_info Optional named list, one element per predator, of
#'   `list(desc =, photo =, credit =, author =, license =, url =)`.
#' @param image_dir,photo_source,licenses Passed to [dv_species_card_assets()].
#'   Defaults: a folder in [tempdir()], no network access, and only openly
#'   licensed iNaturalist photos (CC0, CC BY, CC BY-SA).
#' @param na_strata `"drop"` (default) leaves records with a missing covariate
#'   value out of that covariate's panels; `"show"` draws them in an "NA"
#'   panel. The aggregated sunburst always holds every record. Same argument in
#'   [run_dietview()].
#' @param min_stomachs Minimum number of stomachs for a covariate panel to be
#'   drawn (default 0: every panel is drawn). A panel with fewer stomachs keeps
#'   its header and its "Stomachs (n) = k" line, followed by "Too few stomachs
#'   to show (minimum: ...)" in place of the sunburst. For example, with
#'   `min_stomachs = 10` a year with 4 stomachs is not drawn, while the year
#'   next to it with 522 stomachs is. The aggregated sunburst is always drawn.
#'   Same argument in [run_dietview()] and [dv_script()].
#' @param title Dashboard title.
#' @param self_contained If `TRUE` (default), plotly.js is embedded and the
#'   dashboard is one file. If `FALSE`, plotly.js is written once to a `lib`
#'   folder next to the file and linked, which keeps the HTML small when several
#'   dashboards share a folder. Neither needs pandoc.
#' @return The output path, invisibly.
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
#' # a dashboard for cod, stratified by quarter, written to tempdir()
#' out <- dv_build_html(prep_cod, output = file.path(tempdir(), "cod_dashboard.html"),
#'                      strata = "quarter")
#' file.exists(out)
#' @export
dv_build_html <- function(prep, output,
                          strata = prep$spec$covariates,
                          cross = list(),
                          bands = c("occurrence", "weight"),
                          currency = c("records", "numbers"),
                          length_col = NULL,
                          species_info = list(),
                          image_dir = file.path(tempdir(), "dietview-images"),
                          photo_source = "none",
                          licenses = c("cc0", "cc-by", "cc-by-sa"),
                          na_strata = c("drop", "show"), min_stomachs = 0,
                          title = "DietView", self_contained = TRUE) {
  stopifnot(inherits(prep, "dietview_prep"))
  if (missing(output)) stop("Name the output file: `output = \"my_dashboard.html\"`.",
                            call. = FALSE)
  currency <- match.arg(currency)
  bands <- match.arg(bands, c("occurrence", "weight", "count"), several.ok = TRUE)
  na_strata <- match.arg(na_strata)
  .dv_check_min_stomachs(min_stomachs)
  photo_source <- match.arg(photo_source, c("none", "inaturalist", "wikipedia"),
                            several.ok = TRUE)
  spec <- prep$spec; d <- prep$data; ranks <- prep$ranks
  pcol <- spec$predator; scol <- spec$stomach
  wcol <- spec$weight;  ccol <- .dv_count_col(spec, d, currency)
  if (!is.null(wcol) && !wcol %in% names(d)) wcol <- NULL

  # one node dictionary and one palette, from the pooled tree of the whole prep:
  # every panel's tree is a subset of it, so a taxon has one color everywhere
  pooled <- dv_build_tree(d, ranks = ranks, weight_col = wcol, count_col = ccol)
  colors <- dv_palette_tree(pooled)
  nodes <- list(
    id     = pooled$id,
    label  = pooled$label,
    parent = match(pooled$parent, pooled$id) - 1L,   # 0-based index, -1 = root
    rank   = pooled$rank,
    taxon  = .dv_taxon_display(pooled$label),
    text   = .dv_wedge_text(pooled$label),
    color  = unname(colors[pooled$id]))
  nodes$parent[is.na(nodes$parent)] <- -1L

  rec_lab <- if (currency == "numbers") "Individuals" else "Prey records"
  band_meta <- list(
    occurrence = list(title = if (currency == "numbers") "Individuals (% of all individuals)"
                              else "Prey records (% of all records)", color = "#1f77b4",
                      value = rec_lab, digits = NULL,
                      share = if (currency == "numbers") "Numerical share at this rank (%N)"
                              else "Share of all records at this rank"),
    weight = list(title = "Weight (% of total weight)", color = "#d62728",
                  value = "Weight", digits = 1L, share = "Weight share at this rank"),
    count = list(title = "Distinct prey items", color = "#2c3e50",
                 value = "Distinct prey items", digits = NULL, share = NULL)
  )

  # registries filled while the page is laid out: one subset per set of
  # records (shared by the bands), one panel per drawn sunburst
  reg <- new.env(parent = emptyenv())
  reg$subsets <- list(); reg$keys <- character(0); reg$views <- list(); reg$n <- 0L
  subset_of <- function(recs, key) {
    k <- match(key, reg$keys)
    if (!is.na(k)) return(k - 1L)
    tr <- dv_build_tree(recs, ranks = ranks, weight_col = wcol, count_col = ccol)
    idx <- match(tr$id, pooled$id)
    reg$subsets[[length(reg$subsets) + 1L]] <- list(
      n = idx - 1L, o = tr$value_occ, w = signif(tr$value_w, 6),
      i = if ("count" %in% bands) tr$value_item)
    reg$keys <- c(reg$keys, key)
    length(reg$subsets) - 1L
  }
  panel <- function(recs, mode, view, key, ttl = "") {
    reg$n <- reg$n + 1L
    div <- paste0("dvsb", reg$n)
    v <- reg$views[[view]]
    if (is.null(v)) v <- list()
    v[[length(v) + 1L]] <- list(d = jsonlite::unbox(div),
                                s = jsonlite::unbox(subset_of(recs, key)),
                                b = jsonlite::unbox(mode), t = jsonlite::unbox(ttl))
    reg$views[[view]] <- v
    htmltools::tags$div(id = div, class = "dv-sb")
  }

  nstom <- function(recs) length(unique(recs[[scol]]))
  # a covariate cell below min_stomachs keeps its header and stomach count but
  # no sunburst (and no data in the JSON)
  cell_panel <- function(sub, mode, view, key) {
    if (nstom(sub) < min_stomachs)
      htmltools::tags$p(class = "dv-few", .dv_few_msg(min_stomachs))
    else panel(sub, mode, view, key)
  }
  # covariate values as panel labels: missing values become "NA" (shown) or
  # NA (dropped)
  cov_val <- function(x) {
    v <- as.character(x)
    miss <- is.na(v) | v == "" | v == "NA"
    v[miss] <- if (na_strata == "show") "NA" else NA_character_
    v
  }
  levs <- function(recs, cv) {
    v <- sort(unique(cov_val(recs[[cv]])))
    v[!is.na(v)]
  }
  rng <- function(x) {
    x <- stats::na.omit(x); if (!length(x)) return("N/A")
    paste0(round(min(x), 1), " - ", round(max(x), 1))
  }
  cell_style <- function(n) paste0("width:", max(20, floor(100 / n)),
                                   "%;float:left;padding:8px;text-align:center;box-sizing:border-box;")

  band_row <- function(recs, mode, cv, view) {
    lv <- levs(recs, cv); if (!length(lv)) return(NULL)
    cells <- lapply(lv, function(l) {
      sub <- recs[which(cov_val(recs[[cv]]) == l), ]
      htmltools::tags$div(
        style = cell_style(length(lv)),
        htmltools::tags$h5(paste0(cv, ": ", l)),
        htmltools::tags$h6(paste("Stomachs (n) =", nstom(sub))),
        cell_panel(sub, mode, view, paste(view, cv, l, sep = "\r")))
    })
    htmltools::tagList(
      htmltools::tags$hr(style = "clear:both;margin-top:25px;"),
      htmltools::tags$h4(paste("By", cv), style = "text-align:center;"),
      htmltools::tags$div(style = "width:100%;overflow:hidden;", cells))
  }

  band_cross <- function(recs, mode, inner, outer, view) {
    ol <- levs(recs, outer); if (!length(ol)) return(NULL)
    blocks <- lapply(ol, function(o) {
      ro <- recs[which(cov_val(recs[[outer]]) == o), ]
      il <- levs(ro, inner); if (!length(il)) return(NULL)
      cells <- lapply(il, function(i) {
        sub <- ro[which(cov_val(ro[[inner]]) == i), ]
        htmltools::tags$div(
          style = cell_style(length(il)),
          htmltools::tags$h5(paste0(inner, ": ", i)),
          htmltools::tags$h6(paste("Stomachs (n) =", nstom(sub))),
          cell_panel(sub, mode, view, paste(view, inner, i, outer, o, sep = "\r")))
      })
      htmltools::tagList(
        htmltools::tags$h5(paste0(outer, ": ", o),
                           style = "text-align:center;color:#8c564b;margin-top:15px;clear:both;"),
        htmltools::tags$div(style = "width:100%;overflow:hidden;", cells))
    })
    htmltools::tagList(
      htmltools::tags$hr(style = "clear:both;margin-top:25px;"),
      htmltools::tags$h4(paste(inner, "by", outer), style = "text-align:center;color:#8c564b;"),
      blocks)
  }

  build_band <- function(recs, mode, view) {
    m <- band_meta[[mode]]
    htmltools::tags$div(
      class = "diet-band",
      style = paste0("border-top:4px solid ", m$color, ";margin-top:35px;padding-top:10px;"),
      htmltools::tags$h2(m$title, style = paste0("text-align:center;color:", m$color, ";")),
      panel(recs, mode, view, paste(view, "all", sep = "\r"), "Aggregated"),
      lapply(strata, function(cv) band_row(recs, mode, cv, view)),
      lapply(cross, function(pr) band_cross(recs, mode, pr[1], pr[2], view)))
  }

  card_open <- function(view) list(
    role = "button", tabindex = "0",
    onclick = sprintf("showTab('%s')", view),
    onkeydown = sprintf("cardKey(event,'%s')", view))

  preds <- sort(unique(as.character(d[[pcol]])))
  n_na_pred <- sum(is.na(d[[pcol]]))
  if (n_na_pred)
    warning(n_na_pred, " record(s) have no predator; they appear only in the ",
            "Global view.", call. = FALSE)
  cards <- list(); tabs <- list()

  # Global
  tabs[["__g"]] <- htmltools::tags$div(
    id = "view_global", class = "dashboard-view",
    htmltools::tags$button(class = "btn-back", onclick = "showTab('view_home')", "\u2b05 Home"),
    htmltools::tags$h2("Global", style = "text-align:center;"),
    htmltools::tags$h4(paste("Total stomachs:", nstom(d)), style = "text-align:center;color:#555;"),
    lapply(bands, function(m) build_band(d, m, "view_global")))
  cards[["__g"]] <- do.call(htmltools::tags$div, c(
    list(class = "species-card", `data-order` = "0",
         style = "border:2px solid #1f77b4;background:#f0f8ff;"),
    card_open("view_global"),
    list(htmltools::tags$h3(class = "card-title", "\U0001F310 Global"),
         htmltools::tags$p(class = "card-stat", htmltools::tags$b("Total stomachs: "), nstom(d)))))

  for (i in seq_along(preds)) {
    p <- preds[i]; recs <- d[which(as.character(d[[pcol]]) == p), ]
    # the index keeps ids unique ("A-b" and "A b" would otherwise collide)
    pid <- paste0("p", i, "_", gsub("[^A-Za-z0-9]", "_", p))
    view <- paste0("view_", pid)
    latin <- if (!is.null(spec$predator_latin)) as.character(recs[[spec$predator_latin]])[1] else NA
    a <- dv_species_card_assets(p, latin, species_info[[p]], image_dir = image_dir,
                                photo_source = photo_source, licenses = licenses)
    len_line <- if (!is.null(length_col) && length_col %in% names(recs))
      htmltools::tags$p(class = "card-stat", htmltools::tags$b("Length: "), rng(recs[[length_col]])) else NULL

    cards[[p]] <- do.call(htmltools::tags$div, c(
      list(class = "species-card", `data-order` = as.character(i)),
      card_open(view),
      list(
        htmltools::tags$h3(class = "card-title", p),
        if (!is.null(a$desc)) htmltools::tags$p(class = "species-desc", a$desc,
                                                if (!is.null(a$desc_credit))
                                                  htmltools::tags$span(class = "desc-credit", a$desc_credit)),
        htmltools::tags$div(
          class = "card-body",
          htmltools::tags$div(class = "card-stats",
                              htmltools::tags$p(class = "card-stat", htmltools::tags$b("Total stomachs: "), nstom(recs)),
                              len_line),
          if (!is.null(a$uri))
            htmltools::tags$div(
              class = "photo-box",
              htmltools::tags$img(class = "species-photo", src = a$uri, alt = paste("ID:", p)),
              if (!is.null(a$credit))
                htmltools::tags$span(class = "photo-credit",
                                     if (!is.null(a$url))
                                       htmltools::tags$a(href = a$url, target = "_blank",
                                                         rel = "noopener",
                                                         onclick = "event.stopPropagation()",
                                                         a$credit)
                                     else a$credit))))))

    tabs[[p]] <- htmltools::tags$div(
      id = view, class = "dashboard-view",
      htmltools::tags$button(class = "btn-back", onclick = "showTab('view_home')", "\u2b05 Home"),
      htmltools::tags$h2(p, style = "text-align:center;"),
      htmltools::tags$h4(paste("Total stomachs:", nstom(recs)), style = "text-align:center;color:#555;"),
      lapply(bands, function(m) build_band(recs, m, view)))
  }

  data <- list(nodes = nodes,
               bands = lapply(band_meta[bands], function(m) lapply(
                 m[c("value", "digits", "share")],
                 function(x) if (is.null(x)) NULL else jsonlite::unbox(x))),
               subsets = reg$subsets, views = reg$views)
  body <- htmltools::tagList(.dv_home(title, cards, currency, bands), htmltools::tagList(tabs))
  .dv_write_dashboard(body, data, output, title, self_contained)
  invisible(output)
}

#' Deploy the dashboard as a standalone HTML file
#'
#' Thin wrapper over [dv_build_html()] that writes the self-contained dashboard
#' into `dir` (e.g. a folder served by your web platform) and returns its path.
#'
#' @param prep A `dietview_prep`.
#' @param file Output file name.
#' @param dir Destination directory (created if needed). Required, so the
#'   function never writes to the working directory by default.
#' @param ... Passed to [dv_build_html()].
#' @return The output path, invisibly.
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
#' \donttest{
#' dv_deploy(prep_cod, file = "cod_dashboard.html", dir = tempdir(),
#'           strata = character(0))
#' }
#' @export
dv_deploy <- function(prep, file = "dietview_dashboard.html", dir, ...) {
  if (missing(dir)) stop("Name the destination folder: `dir = \"my_folder\"`.",
                         call. = FALSE)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(normalizePath(dir, winslash = "/", mustWork = TRUE), file)
  dv_build_html(prep, output = path, ...)
  if (file.exists(path)) message("Deployed standalone dashboard: ", path)
  else warning("Render finished but no file at: ", path, call. = FALSE)
  invisible(path)
}

# --- internal UI pieces -------------------------------------------------------

.dv_css <- "
      body{font-family:sans-serif;background:#f8f9fa;margin:0;padding:20px}
      .dashboard-view{display:none;background:#fff;padding:30px;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,.1)}
      .dashboard-view.active{display:block}
      .species-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:20px;margin-top:30px}
      .species-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:20px;cursor:pointer;transition:.2s}
      .species-card:hover,.species-card:focus{transform:translateY(-4px);box-shadow:0 8px 12px rgba(0,0,0,.15);border-color:#1f77b4}
      .species-card:focus{outline:3px solid #1f77b4;outline-offset:2px}
      .card-title{font-size:1.2rem;font-weight:bold;color:#2c3e50;border-bottom:2px solid #aec7e8;padding-bottom:8px;margin:0 0 12px}
      .card-stat{font-size:.9rem;color:#333;margin:8px 0}
      .species-desc{font-size:.82rem;color:#555;font-style:italic;margin:-4px 0 12px}
      .card-body{display:flex;gap:15px;align-items:flex-start;justify-content:space-between}
      .card-stats{flex:1 1 auto;min-width:0}
      .species-photo{width:130px;max-height:130px;object-fit:cover;border-radius:6px;border:1px solid #ddd;flex:0 0 auto}
      .photo-box{display:flex;flex-direction:column;align-items:flex-end;flex:0 0 130px}
      .photo-credit{display:block;width:130px;font-size:.65rem;color:#777;line-height:1.2;margin-top:3px;text-align:right}
      .photo-credit a{color:#777}
      .desc-credit{display:block;font-size:.65rem;font-style:normal;color:#999;margin-top:2px}
      .diet-band{margin-bottom:25px}
      .dv-few{color:#777;font-style:italic;padding:20px 0}
      .dv-sb{width:100%;height:400px}
      .btn-back{padding:10px 20px;background:#1f77b4;color:#fff;border:none;border-radius:5px;cursor:pointer;font-weight:bold;margin-bottom:20px}
      .controls{display:flex;gap:15px;align-items:center;flex-wrap:wrap;margin:15px 0}
      .controls input,.controls select{padding:10px;border-radius:5px;border:1px solid #ccc;font-size:1rem}
"

# Draws the sunbursts of a tab from the JSON block the first time it is shown.
# Wedge text is N.text (blank for unidentified "NA" nodes, as in .dv_sb_prep()).
# The hover text follows .dv_sb_prep(): rank, taxon, value and, except for
# distinct items, the share of the ring.
.dv_js <- "
      var DV = JSON.parse(document.getElementById('dv-data').textContent);
      var DV_DONE = {};
      function dvTrace(p){
        var N = DV.nodes, S = DV.subsets[p.s], B = DV.bands[p.b];
        var val = p.b === 'weight' ? S.w : (p.b === 'count' ? S.i : S.o);
        var isParent = {}, rankSum = {};
        S.n.forEach(function(k, j){
          if (N.parent[k] >= 0) isParent[N.parent[k]] = true;
          rankSum[N.rank[k]] = (rankSum[N.rank[k]] || 0) + val[j];
        });
        var t = {type:'sunburst', ids:[], labels:[], parents:[], values:[], text:[], hovertext:[],
                 branchvalues:'remainder', sort:false, rotation:90, textinfo:'text',
                 hovertemplate:'%{hovertext}<extra></extra>',
                 marker:{colors:[], line:{color:'#8C8C8C', width:0.5}}};
        S.n.forEach(function(k, j){
          var v = val[j], den = rankSum[N.rank[k]];
          t.ids.push(N.id[k]); t.labels.push(N.label[k]); t.text.push(N.text[k]);
          t.parents.push(N.parent[k] < 0 ? '' : N.id[N.parent[k]]);
          t.values.push(isParent[k] ? 0 : v); t.marker.colors.push(N.color[k]);
          var h = '<b>Rank:</b> ' + N.rank[k] + '<br><b>Taxon:</b> ' + N.taxon[k] +
                  '<br><b>' + B.value + ':</b> ' + (B.digits != null ? v.toFixed(B.digits) : v);
          if (B.share != null)
            h += '<br><b>' + B.share + ':</b> ' + (den > 0 ? (100 * v / den).toFixed(1) + '%' : 'n/a');
          t.hovertext.push(h);
        });
        return t;
      }
      function dvRender(id){
        if (DV_DONE[id] || !DV.views[id]) return;
        DV_DONE[id] = true;
        DV.views[id].forEach(function(p){
          Plotly.newPlot(p.d, [dvTrace(p)],
            {title:{text:p.t, font:{size:14}}, margin:{t:p.t ? 50 : 20, l:10, r:10, b:10}},
            {responsive:true, displaylogo:false});
        });
      }
      function showTab(id){
        document.querySelectorAll('.dashboard-view').forEach(function(v){v.classList.remove('active');});
        document.getElementById(id).classList.add('active');
        dvRender(id);
        window.dispatchEvent(new Event('resize')); window.scrollTo(0,0);
      }
      function cardKey(e, id){
        if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar'){ e.preventDefault(); showTab(id); }
      }
      function filterCards(){var f=document.getElementById('searchBox').value.toUpperCase();
        document.querySelectorAll('#cards_container .species-card').forEach(function(c){
          var t=c.querySelector('.card-title');c.style.display=(t&&t.textContent.toUpperCase().indexOf(f)>-1)?'':'none';});}
      function sortCards(){var box=document.getElementById('cards_container');
        var cards=Array.from(box.getElementsByClassName('species-card'));
        var v=document.getElementById('sortBox').value;
        var g=cards.find(function(c){return c.getAttribute('data-order')==='0';});
        var s=cards.filter(function(c){return c.getAttribute('data-order')!=='0';});
        if(v==='az'||v==='za'){s.sort(function(a,b){var ta=a.querySelector('.card-title').textContent.trim(),
          tb=b.querySelector('.card-title').textContent.trim();return v==='az'?ta.localeCompare(tb):tb.localeCompare(ta);});}
        else{s.sort(function(a,b){return parseInt(a.getAttribute('data-order'))-parseInt(b.getAttribute('data-order'));});}
        box.innerHTML='';if(g)box.appendChild(g);s.forEach(function(c){box.appendChild(c);});}
"

.dv_home <- function(title, cards, currency = "records",
                     bands = c("occurrence", "weight", "count")) {
  band_txt <- c(
    occurrence = if (currency == "numbers") "individuals (% of all individuals)"
                 else "prey records (% of all records)",
    weight = "weight (% of total weight)",
    count = "distinct prey items")[bands]
  band_txt <- if (length(band_txt) > 1)
    paste(paste(band_txt[-length(band_txt)], collapse = ", "), "and", band_txt[length(band_txt)])
  else band_txt
  htmltools::tags$div(
    id = "view_home", class = "dashboard-view active",
    htmltools::tags$h1(title),
    htmltools::tags$p(
      paste0("Click a card (or press Enter on it) to open a predator's diet: sunbursts of ", band_txt, ". White wedges are records not identified at that rank; gray wedges are identified material in groups that have no taxon at that rank in WoRMS. Both are kept, so every ring accounts for all the material and its shares sum to 100%.")
    ),
    htmltools::tags$div(
      class = "controls",
      htmltools::tags$input(
        type = "text", id = "searchBox", placeholder = "Search species...",
        `aria-label` = "Search species",
        onkeyup = "filterCards()", style = "width:300px;"
      ),
      htmltools::tags$select(
        id = "sortBox", onchange = "sortCards()", `aria-label` = "Sort cards",
        htmltools::tags$option(value = "default", "Sort: Default"),
        htmltools::tags$option(value = "az", "Sort: A-Z"),
        htmltools::tags$option(value = "za", "Sort: Z-A")
      )
    ),
    htmltools::tags$div(id = "cards_container", class = "species-grid", cards)
  )
}

# Internal: `min_stomachs` of dv_build_html(), run_dietview() and dv_script().
.dv_check_min_stomachs <- function(x) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < 0)
    stop("`min_stomachs` must be a single number >= 0.", call. = FALSE)
  invisible(x)
}

# Internal: the line shown in place of a covariate panel with too few stomachs.
.dv_few_msg <- function(min_stomachs)
  paste0("Too few stomachs to show (minimum: ", format(min_stomachs), ")")

# Internal: the plotly.js bundle shipped with the plotly R package.
.dv_plotly_js <- function() {
  f <- system.file("htmlwidgets", "lib", "plotlyjs", "plotly-latest.min.js",
                   package = "plotly")
  if (!nzchar(f)) stop("plotly.js was not found in the 'plotly' package.", call. = FALSE)
  f
}

# Internal: write the dashboard page: plotly.js once (inline or in lib/), the
# sunburst data as one JSON block, then the page script.
.dv_write_dashboard <- function(body, data, output, title, self_contained) {
  # Resolve to an absolute path from the (created) directory: on Windows
  # normalizePath() leaves a relative path to a file that does not exist yet
  # untouched.
  out_dir <- dirname(output)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir, winslash = "/", mustWork = TRUE)
  out_abs <- file.path(out_dir, basename(output))

  js_file <- .dv_plotly_js()
  plotly_tag <- if (isTRUE(self_contained)) {
    # read as bytes: readLines() would turn lone carriage returns inside the
    # minified JS strings into line breaks and break the bundle
    js <- rawToChar(readBin(js_file, "raw", file.size(js_file)))
    Encoding(js) <- "UTF-8"
    paste0("<script>", js, "</script>")
  } else {
    lib <- file.path(out_dir, "lib", "plotlyjs")
    dir.create(lib, recursive = TRUE, showWarnings = FALSE)
    file.copy(js_file, file.path(lib, basename(js_file)), overwrite = TRUE)
    sprintf("<script src=\"lib/plotlyjs/%s\"></script>", basename(js_file))
  }

  json <- jsonlite::toJSON(data, digits = NA, na = "null", null = "null",
                           auto_unbox = FALSE)
  # nothing in the data may close the script element
  json <- gsub("</", "<\\/", json, fixed = TRUE)
  html <- c(
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    paste0("<title>", htmltools::htmlEscape(title), "</title>"),
    paste0("<style>", .dv_css, "</style>"),
    plotly_tag,
    "</head>",
    "<body>",
    as.character(htmltools::doRenderTags(body)),
    paste0("<script type=\"application/json\" id=\"dv-data\">", json, "</script>"),
    paste0("<script>", .dv_js, "</script>"),
    "</body>",
    "</html>")
  con <- file(out_abs, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste(html, collapse = "\n"))), con)
  invisible(out_abs)
}
