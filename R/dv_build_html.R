#' Build a self-contained HTML diet dashboard
#'
#' Reproduces the sGSL-style dashboard from any prepared dataset: a searchable,
#' sortable landing grid of predator cards (stomach counts, length range, ID
#' photo, description) plus one tab per predator. Each tab shows the diet in up
#' to three bands (occurrence items, occurrence %, weight %); each band repeats
#' the same structure: an aggregated sunburst, one row of sunbursts per declared
#' covariate, and optionally crossed rows (e.g. length bins split by period).
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param output Output HTML path.
#' @param strata Covariates to stratify each band by (default: all declared).
#' @param cross List of `c(inner, outer)` covariate pairs to also show crossed
#'   (for each level of `outer`, a row of `inner` levels). E.g.
#'   `list(c("size_bin", "period"))`.
#' @param bands Which bands to draw and in which order.
#' @param length_col Optional numeric length column, to show length ranges on cards.
#' @param species_info Optional named list of `list(desc=, photo=)` per predator.
#' @param image_dir,use_wiki Passed to [dv_species_card_assets()].
#' @param title Dashboard title.
#' @param self_contained If TRUE render a single embedded file (needs rmarkdown).
#' @return The output path, invisibly.
#' @examples
#' csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
#' lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
#' dat <- read.csv(csv, na.strings = c("NA", ""))
#' lineage <- read.csv(lin, na.strings = c("NA", ""))
#' spec <- dv_spec(predator = "predator_species_common_name",
#'                 stomach = "stomach_id",
#'                 prey_id = "aphia_id",
#'                 prey_name = "verified_name",
#'                 weight = "prey_weight", digestion = "digestion_level_id")
#' prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
#'                    verbose = FALSE)
#' \dontrun{
#' # writes a self-contained HTML dashboard
#' dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"),
#'               strata = c("period", "size_class"))
#' }
#' @export
dv_build_html <- function(prep, output = "dietview.html",
                          strata = prep$spec$covariates,
                          cross = list(),
                          bands = c("count", "occurrence", "weight"),
                          length_col = NULL,
                          species_info = list(),
                          image_dir = "images", use_wiki = TRUE,
                          title = "DietView", self_contained = TRUE) {
  stopifnot(inherits(prep, "dietview_prep"))
  spec <- prep$spec; d <- prep$data; ranks <- prep$ranks
  pcol <- spec$predator; scol <- spec$stomach
  wcol <- spec$weight;  ccol <- spec$count

  colors <- dv_palette(unlist(lapply(ranks, function(r) .dv_fill_na(d[[r]]))))
  band_meta <- list(
    count = list(title = "Band 1 - Distinct diet counts", color = "#2c3e50"),
    occurrence = list(title = "Band 2 - Occurrence share within rank", color = "#1f77b4"),
    weight = list(title = "Band 3 - Weight share within rank", color = "#d62728")
  )

  sb <- function(recs, mode, ttl = "", sub = "")
    dv_sunburst(recs, mode = mode, ranks = ranks, weight_col = wcol,
                count_col = ccol, colors = colors, title = ttl, subtitle = sub)
  nstom <- function(recs) length(unique(recs[[scol]]))
  levs <- function(recs, cv) {
    v <- sort(unique(as.character(recs[[cv]])))
    v[!is.na(v) & v != "NA" & v != ""]
  }
  rng <- function(x) {
    x <- stats::na.omit(x); if (!length(x)) return("N/A")
    paste0(round(min(x), 1), " - ", round(max(x), 1))
  }

  band_row <- function(recs, mode, cv, header = paste("By", cv)) {
    lv <- levs(recs, cv); if (!length(lv)) return(NULL)
    pw <- max(20, floor(100 / length(lv)))
    cells <- lapply(lv, function(l) {
      sub <- recs[which(as.character(recs[[cv]]) == l), ]
      htmltools::tags$div(
        style = paste0("width:", pw, "%;float:left;padding:8px;text-align:center;box-sizing:border-box;"),
        htmltools::tags$h5(paste0(cv, ": ", l)),
        htmltools::tags$h6(paste("Stomachs (n) =", nstom(sub))),
        sb(sub, mode))
    })
    htmltools::tagList(
      htmltools::tags$hr(style = "clear:both;margin-top:25px;"),
      htmltools::tags$h4(header, style = "text-align:center;"),
      htmltools::tags$div(style = "width:100%;overflow:hidden;", cells))
  }

  band_cross <- function(recs, mode, inner, outer) {
    ol <- levs(recs, outer); if (!length(ol)) return(NULL)
    blocks <- lapply(ol, function(o) {
      ro <- recs[which(as.character(recs[[outer]]) == o), ]
      il <- levs(ro, inner); if (!length(il)) return(NULL)
      pw <- max(20, floor(100 / length(il)))
      cells <- lapply(il, function(i) {
        sub <- ro[which(as.character(ro[[inner]]) == i), ]
        htmltools::tags$div(
          style = paste0("width:", pw, "%;float:left;padding:8px;text-align:center;box-sizing:border-box;"),
          htmltools::tags$h5(paste0(inner, ": ", i)),
          htmltools::tags$h6(paste("Stomachs (n) =", nstom(sub))),
          sb(sub, mode))
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

  build_band <- function(recs, mode) {
    m <- band_meta[[mode]]
    htmltools::tags$div(
      class = "diet-band",
      style = paste0("border-top:4px solid ", m$color, ";margin-top:35px;padding-top:10px;"),
      htmltools::tags$h2(m$title, style = paste0("text-align:center;color:", m$color, ";")),
      sb(recs, mode, "Aggregated"),
      lapply(strata, function(cv) band_row(recs, mode, cv)),
      lapply(cross, function(pr) band_cross(recs, mode, pr[1], pr[2])))
  }

  preds <- sort(unique(as.character(d[[pcol]])))
  cards <- list(); tabs <- list()

  # Global
  tabs[["__g"]] <- htmltools::tags$div(
    id = "view_global", class = "dashboard-view",
    htmltools::tags$button(class = "btn-back", onclick = "showTab('view_home')", "\u2b05 Home"),
    htmltools::tags$h2("Global", style = "text-align:center;"),
    htmltools::tags$h4(paste("Total stomachs:", nstom(d)), style = "text-align:center;color:#555;"),
    lapply(bands, function(m) build_band(d, m)))
  cards[["__g"]] <- htmltools::tags$div(
    class = "species-card", `data-order` = "0", onclick = "showTab('view_global')",
    style = "border:2px solid #1f77b4;background:#f0f8ff;",
    htmltools::tags$h3(class = "card-title", "\U0001F310 Global"),
    htmltools::tags$p(class = "card-stat", htmltools::tags$b("Total stomachs: "), nstom(d)))

  for (i in seq_along(preds)) {
    p <- preds[i]; recs <- d[which(as.character(d[[pcol]]) == p), ]
    pid <- gsub("[^A-Za-z0-9]", "_", p)
    latin <- if (!is.null(spec$predator_latin)) as.character(recs[[spec$predator_latin]])[1] else NA
    a <- dv_species_card_assets(p, latin, species_info[[p]], image_dir, use_wiki)
    len_line <- if (!is.null(length_col) && length_col %in% names(recs))
      htmltools::tags$p(class = "card-stat", htmltools::tags$b("Length: "), rng(recs[[length_col]])) else NULL

    cards[[p]] <- htmltools::tags$div(
      class = "species-card", `data-order` = as.character(i),
      onclick = sprintf("showTab('view_%s')", pid),
      htmltools::tags$h3(class = "card-title", p),
      if (!is.null(a$desc)) htmltools::tags$p(class = "species-desc", a$desc),
      htmltools::tags$div(class = "card-body",
                          htmltools::tags$div(class = "card-stats",
                                              htmltools::tags$p(class = "card-stat", htmltools::tags$b("Total stomachs: "), nstom(recs)),
                                              len_line),
                          if (!is.null(a$uri))
                            htmltools::tags$div(class = "photo-box",
                                                htmltools::tags$img(class = "species-photo", src = a$uri, alt = paste("ID:", p)),
                                                if (!is.null(a$credit))
                                                  htmltools::tags$span(class = "photo-credit", a$credit))))

    tabs[[p]] <- htmltools::tags$div(
      id = paste0("view_", pid), class = "dashboard-view",
      htmltools::tags$button(class = "btn-back", onclick = "showTab('view_home')", "\u2b05 Home"),
      htmltools::tags$h2(p, style = "text-align:center;"),
      htmltools::tags$h4(paste("Total stomachs:", nstom(recs)), style = "text-align:center;color:#555;"),
      lapply(bands, function(m) build_band(recs, m)))
  }

  page <- htmltools::tagList(.dv_head_tags(), .dv_home(title, cards), htmltools::tagList(tabs))
  .dv_render(page, output, title, self_contained)
  invisible(output)
}

#' Deploy the dashboard as a standalone HTML file
#'
#' Thin wrapper over [dv_build_html()] that writes the self-contained dashboard
#' into `dir` (e.g. a folder served by your web platform) and returns its path.
#'
#' @param prep A `dietview_prep`.
#' @param file Output file name.
#' @param dir Destination directory (created if needed).
#' @param ... Passed to [dv_build_html()].
#' @return The output path, invisibly.
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
#' \dontrun{
#' dv_deploy(prep, file = "dietview_dashboard.html", dir = tempdir())
#' }
#' @export
dv_deploy <- function(prep, file = "dietview_dashboard.html", dir = ".", ...) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(normalizePath(dir, winslash = "/", mustWork = TRUE), file)
  dv_build_html(prep, output = path, ...)
  if (file.exists(path)) message("Deployed standalone dashboard: ", path)
  else warning("Render finished but no file at: ", path, call. = FALSE)
  invisible(path)
}

# --- internal UI pieces -------------------------------------------------------

.dv_head_tags <- function() {
  htmltools::tagList(
    htmltools::tags$style(htmltools::HTML("
      body{font-family:sans-serif;background:#f8f9fa;margin:0;padding:20px}
      .dashboard-view{display:none;background:#fff;padding:30px;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,.1)}
      .dashboard-view.active{display:block}
      .species-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:20px;margin-top:30px}
      .species-card{background:#fff;border:1px solid #ddd;border-radius:8px;padding:20px;cursor:pointer;transition:.2s}
      .species-card:hover{transform:translateY(-4px);box-shadow:0 8px 12px rgba(0,0,0,.15);border-color:#1f77b4}
      .card-title{font-size:1.2rem;font-weight:bold;color:#2c3e50;border-bottom:2px solid #aec7e8;padding-bottom:8px;margin:0 0 12px}
      .card-stat{font-size:.9rem;color:#333;margin:8px 0}
      .species-desc{font-size:.82rem;color:#555;font-style:italic;margin:-4px 0 12px}
      .card-body{display:flex;gap:15px;align-items:flex-start;justify-content:space-between}
      .card-stats{flex:1 1 auto;min-width:0}
      .species-photo{width:130px;max-height:130px;object-fit:cover;border-radius:6px;border:1px solid #ddd;flex:0 0 auto}
      .diet-band{margin-bottom:25px}
      .btn-back{padding:10px 20px;background:#1f77b4;color:#fff;border:none;border-radius:5px;cursor:pointer;font-weight:bold;margin-bottom:20px}
      .controls{display:flex;gap:15px;align-items:center;flex-wrap:wrap;margin:15px 0}
      .controls input,.controls select{padding:10px;border-radius:5px;border:1px solid #ccc;font-size:1rem}
    ")),
    htmltools::tags$script(htmltools::HTML("
      function showTab(id){document.querySelectorAll('.dashboard-view').forEach(v=>v.classList.remove('active'));
        document.getElementById(id).classList.add('active');window.dispatchEvent(new Event('resize'));window.scrollTo(0,0);}
      function filterCards(){var f=document.getElementById('searchBox').value.toUpperCase();
        document.querySelectorAll('#cards_container .species-card').forEach(function(c){
          var t=c.querySelector('.card-title');c.style.display=(t&&t.textContent.toUpperCase().indexOf(f)>-1)?'':'none';});}
      function sortCards(){var box=document.getElementById('cards_container');
        var cards=Array.from(box.getElementsByClassName('species-card'));
        var v=document.getElementById('sortBox').value;
        var g=cards.find(c=>c.getAttribute('data-order')==='0');
        var s=cards.filter(c=>c.getAttribute('data-order')!=='0');
        if(v==='az'||v==='za'){s.sort(function(a,b){var ta=a.querySelector('.card-title').textContent.trim(),
          tb=b.querySelector('.card-title').textContent.trim();return v==='az'?ta.localeCompare(tb):tb.localeCompare(ta);});}
        else{s.sort(function(a,b){return parseInt(a.getAttribute('data-order'))-parseInt(b.getAttribute('data-order'));});}
        box.innerHTML='';if(g)box.appendChild(g);s.forEach(c=>box.appendChild(c));}
    ")))
}

.dv_home <- function(title, cards) {
  htmltools::tags$div(
    id = "view_home", class = "dashboard-view active",
    htmltools::tags$h1(title),
    htmltools::tags$p(
      "Click a card to open a predator's diet. Each predator shows up to three bands: Band 1 shows distinct diet items, Band 2 shows occurrence share within each rank, and Band 3 shows weight share within each rank. White segments are unidentified prey (NA), kept as an explicit category so within-rank percentages sum to 100%."
    ),
    htmltools::tags$div(
      class = "controls",
      htmltools::tags$input(
        type = "text", id = "searchBox", placeholder = "Search species...",
        onkeyup = "filterCards()", style = "width:300px;"
      ),
      htmltools::tags$select(
        id = "sortBox", onchange = "sortCards()",
        htmltools::tags$option(value = "default", "Sort: Default"),
        htmltools::tags$option(value = "az", "Sort: A-Z"),
        htmltools::tags$option(value = "za", "Sort: Z-A")
      )
    ),
    htmltools::tags$div(id = "cards_container", class = "species-grid", cards)
  )
}

.dv_render <- function(page, output, title, self_contained) {
  # Resolve to an ABSOLUTE path. On Windows normalizePath() leaves a relative
  # path untouched when the file does not exist yet; since the temporary .Rmd
  # lives in tempdir(), rmarkdown would then resolve `output` against tempdir()
  # and fail ("directory does not exist"). So normalize the *directory* (which
  # we create first) and rebuild the file path from it.
  out_dir <- dirname(output)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(out_dir, winslash = "/", mustWork = TRUE)
  out_abs <- file.path(out_dir, basename(output))

  if (isTRUE(self_contained) && requireNamespace("rmarkdown", quietly = TRUE)) {
    tmp <- tempfile(fileext = ".Rmd")
    writeLines(c("---", paste0("title: '", title, "'"),
                 "output:", "  html_document:", "    self_contained: true",
                 "---", "```{r echo=FALSE}", "page", "```"), tmp)
    rmarkdown::render(tmp,
                      output_file = basename(out_abs),
                      output_dir  = out_dir,
                      envir = list2env(list(page = page)), quiet = TRUE)
    unlink(tmp)
  } else {
    htmltools::save_html(page, out_abs)
  }
  invisible(out_abs)
}
