#' Launch the interactive DietView app
#'
#' A Shiny explorer over a prepared dataset: pick a predator (or
#' "(all predators)" to pool every predator together), what sizes the wedges
#' (prey records as % of all records, weight as % of total weight, or the number
#' of distinct prey items), the reporting resolution, and optionally one
#' covariate to facet by plus a second one to cross it with (e.g. length bins
#' by period).
#'
#' The reporting resolution is either the full hierarchy (every record at
#' every rank, unidentified material carried outward) or one of the three
#' threshold aggregations of [dv_aggregate_threshold()]: pooled, pooled
#' cross-predator (a category must also span `min_predators` predators) and
#' per predator. Pooled aggregations are computed on all predators before one
#' is selected, so the categories are the same in every predator's view.
#'
#' The tabs show the sunburst (one panel per covariate cell when faceting;
#' records with a missing covariate value are left out of the panels, or shown
#' in an "NA" panel with `na_strata = "show"`), the rank table, the
#' frequency of occurrence at the chosen rank, the digestion diagnostic (when a
#' digestion column is declared) and a "Reproduce" tab. That tab shows the R
#' script that rebuilds the current view with exported functions only (see
#' [dv_script()]) and offers the script, the prepared data it reads and the
#' current tables as downloads.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param currency `"records"` (default: each record counts once) or
#'   `"numbers"` (each record counts its `count` column, %N; needs `count` in
#'   the spec). See [dv_tree()].
#' @param na_strata `"drop"` (default) or `"show"`: whether records with a
#'   missing covariate value get an "NA" panel when faceting. Same argument in
#'   [dv_build_html()].
#' @param min_stomachs Minimum number of stomachs for a facet panel to be
#'   drawn (default 0: every panel is drawn). A panel with fewer stomachs shows
#'   its header, "Stomachs (n) = k" and "Too few stomachs to show (minimum:
#'   ...)" instead of a sunburst; e.g. with `min_stomachs = 10` a year with 4
#'   stomachs is not drawn, while a year with 522 is. The unfaceted sunburst is
#'   always drawn. Same argument in [dv_build_html()] and [dv_script()].
#' @param ... Passed to [shiny::runApp()].
#' @return Called for its side effect of running the app; returns the value
#'   of [shiny::runApp()] once the app is closed.
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
#' if (interactive()) {
#'   run_dietview(prep)
#' }
#' @export
run_dietview <- function(prep, currency = c("records", "numbers"),
                         na_strata = c("drop", "show"), min_stomachs = 0, ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Install 'shiny' to run the app.", call. = FALSE)
  }
  stopifnot(inherits(prep, "dietview_prep"))
  currency <- match.arg(currency)
  na_strata <- match.arg(na_strata)
  .dv_check_min_stomachs(min_stomachs)
  app <- .dv_app(prep, currency, na_strata, min_stomachs)
  shiny::runApp(shiny::shinyApp(app$ui, app$server), ...)
}

# Internal: UI and server of the app, separated from runApp() so they can be
# tested with shiny::testServer().
.dv_app <- function(prep, currency = "records", na_strata = "drop",
                    min_stomachs = 0) {
  spec <- prep$spec; d <- prep$data; ranks <- prep$ranks
  ccol <- .dv_count_col(spec, d, currency)
  rec_lab <- if (currency == "numbers") "Individuals (% of all individuals)"
             else "Prey records (% of all records)"
  ALL_PRED <- "(all predators)"
  preds <- c(ALL_PRED, sort(unique(as.character(d[[spec$predator]]))))
  covs <- c("(none)", spec$covariates)
  has_dig <- !is.null(spec$digestion) && spec$digestion %in% names(d)
  n_stom_min <- min(tapply(as.character(d[[spec$stomach]]),
                           as.character(d[[spec$predator]]),
                           function(z) length(unique(z))))
  res_choices <- c("Full hierarchy (no aggregation)" = "none",
                   "Threshold: pooled" = "pooled",
                   "Threshold: pooled cross-predator" = "cross",
                   "Threshold: per predator" = "per_predator")
  has_dt <- requireNamespace("DT", quietly = TRUE)
  tbl_out <- function(id) if (has_dt) DT::DTOutput(id) else shiny::tableOutput(id)

  ui <- shiny::fluidPage(
    shiny::titlePanel("DietView"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::selectInput("predator", "Predator", choices = preds),
        shiny::radioButtons("mode", "Size wedges by",
                            stats::setNames(c("occurrence", "weight", "count"),
                                            c(rec_lab,
                                              "Weight (% of total weight)",
                                              "Number of distinct prey items"))),
        shiny::selectInput("resolution", "Reporting resolution", choices = res_choices),
        shiny::conditionalPanel(
          "input.resolution != 'none'",
          shiny::numericInput("threshold", "Minimum number of stomachs per category",
                              value = max(1L, ceiling(0.01 * n_stom_min)), min = 1, step = 1)
        ),
        shiny::conditionalPanel(
          "input.resolution == 'cross'",
          shiny::numericInput("min_predators", "Minimum number of predators per category",
                              value = 2, min = 2, step = 1)
        ),
        shiny::selectInput("facet", "Facet by covariate", choices = covs),
        shiny::selectInput("cross", "Cross with (second covariate)",
                           choices = covs),
        shiny::selectInput("rank", "Rank for the tables",
                           choices = .dv_titlecase(ranks),
                           selected = .dv_titlecase(ranks)[min(3, length(ranks))])
      ),
      shiny::mainPanel(
        shiny::tabsetPanel(
          id = "tabs",
          shiny::tabPanel("Sunburst",
                          shiny::helpText("White wedges are records not identified at that",
                                          "rank; gray wedges are identified material in groups",
                                          "that have no taxon at that rank in WoRMS. Both are",
                                          "kept, so every ring accounts for all the material",
                                          "and its shares sum to 100%."),
                          shiny::textOutput("res_note"),
                          plotly::plotlyOutput("sunburst", height = "600px")),
          shiny::tabPanel("Rank table",
                          shiny::helpText("Shares of all records (pct_occ) and of all weight",
                                          "(pct_w) at the chosen rank; each rank sums to 100%,",
                                          "\"NA\" rows are material not identified at that rank;",
                                          "\"(no <rank>)\" rows are identified material in groups",
                                          "with no taxon at that rank in WoRMS."),
                          tbl_out("tbl")),
          shiny::tabPanel("Frequency of occurrence",
                          shiny::helpText("Share of stomachs containing each taxon at the",
                                          "chosen rank; does not sum to 100% across taxa."),
                          tbl_out("fo")),
          if (has_dig) shiny::tabPanel("Digestion",
                          shiny::helpText("Deepest identified rank of each record, by",
                                          "digestion stage (% of records and of weight)."),
                          tbl_out("dig")),
          shiny::tabPanel("Reproduce",
                          shiny::helpText("This script rebuilds the current view with exported",
                                          "DietView functions. Download it together with the",
                                          "prepared data it reads."),
                          shiny::downloadButton("dl_script", "R script"),
                          shiny::downloadButton("dl_prep", "Prepared data (.rds)"),
                          shiny::downloadButton("dl_tbl", "Rank table (.csv)"),
                          shiny::downloadButton("dl_fo", "Frequency of occurrence (.csv)"),
                          shiny::tags$pre(shiny::textOutput("script")))
        )
      )
    )
  )

  server <- function(input, output, session) {
    aggregation <- shiny::reactive({
      if (identical(input$resolution, "none")) return(NULL)
      th <- input$threshold
      shiny::validate(shiny::need(is.numeric(th) && !is.na(th) && th >= 1,
                                  "The threshold must be a number of stomachs >= 1."))
      switch(input$resolution,
             pooled = list(threshold = th, scope = "pooled", min_predators = 1L),
             cross = list(threshold = th, scope = "pooled",
                          min_predators = max(2L, as.integer(input$min_predators %||% 2L))),
             per_predator = list(threshold = th, scope = "per_predator", min_predators = 1L))
    })
    # aggregation runs on all predators, before one is selected
    prep_res <- shiny::reactive({
      a <- aggregation()
      if (is.null(a)) prep
      else dv_aggregate_threshold(prep, threshold = a$threshold, scope = a$scope,
                                  min_predators = a$min_predators)
    })
    prep_sel <- shiny::reactive({
      p <- prep_res()
      if (!identical(input$predator, ALL_PRED))
        p$data <- p$data[which(as.character(p$data[[spec$predator]]) == input$predator), ]
      p
    })
    recs <- shiny::reactive(prep_sel()$data)
    colors <- shiny::reactive({
      # one palette from the pooled tree of all predators (after aggregation)
      dv_palette_tree(dv_build_tree(prep_res()$data, ranks = ranks))
    })
    tree <- shiny::reactive(
      dv_build_tree(recs(), ranks = ranks, weight_col = spec$weight, count_col = ccol)
    )
    facets <- shiny::reactive({
      if (identical(input$facet, "(none)")) return(NULL)
      if (!identical(input$cross, "(none)") && !identical(input$cross, input$facet))
        c(input$facet, input$cross)   # c(inner, outer)
      else input$facet
    })
    output$res_note <- shiny::renderText({
      a <- attr(prep_res(), "aggregation")
      if (is.null(a)) "Full hierarchy: every record is counted once at every rank."
      else sprintf("%d categories, each found in at least %s stomachs%s%s.",
                   a$n_categories, format(a$threshold),
                   if (a$min_predators > 1) sprintf(" and %d predators", a$min_predators) else "",
                   if (a$scope == "per_predator") " of the same predator" else "")
    })
    output$sunburst <- plotly::renderPlotly({
      fc <- facets()
      if (is.null(fc)) {
        dv_sunburst(tree(), mode = input$mode, colors = colors(),
                    title = input$predator)
      } else {
        .dv_sunburst_facets(
          recs(), ranks = ranks,
          weight_col = spec$weight, count_col = ccol,
          facet_col = fc, mode = input$mode, colors = colors(), na_strata = na_strata,
          stomach_col = spec$stomach, min_stomachs = min_stomachs,
          title = paste0(input$predator, " - ",
                         if (length(fc) == 2L)
                           paste(fc[1], "by", fc[2])
                         else paste("faceted by", fc))
        )
      }
    })
    rank_tbl <- shiny::reactive(dv_rank_table(tree(), input$rank))
    fo_tbl <- shiny::reactive(dv_fo_table(prep_sel(), rank = input$rank))
    dig_tbl <- shiny::reactive(dv_digestion_diagnostic(prep_sel()))
    script <- shiny::reactive(
      dv_script(prep, predator = if (identical(input$predator, ALL_PRED)) NULL else input$predator,
                mode = input$mode, currency = currency, aggregation = aggregation(),
                facet = facets(), rank = input$rank, na_strata = na_strata,
                min_stomachs = min_stomachs)
    )

    show <- function(id, f) {
      output[[id]] <- if (has_dt) DT::renderDT(f(), options = list(pageLength = 15))
                      else shiny::renderTable(f())
    }
    show("tbl", function() as.data.frame(rank_tbl()))
    show("fo", fo_tbl)
    if (has_dig) show("dig", dig_tbl)
    output$script <- shiny::renderText(paste(script(), collapse = "\n"))

    output$dl_script <- shiny::downloadHandler(
      filename = function() "dietview_analysis.R",
      content = function(file) writeLines(script(), file, useBytes = TRUE))
    output$dl_prep <- shiny::downloadHandler(
      filename = function() "dietview_prep.rds",
      content = function(file) saveRDS(prep, file))
    output$dl_tbl <- shiny::downloadHandler(
      filename = function() paste0("rank_table_", tolower(input$rank), ".csv"),
      content = function(file) utils::write.csv(as.data.frame(rank_tbl()), file,
                                                row.names = FALSE))
    output$dl_fo <- shiny::downloadHandler(
      filename = function() paste0("frequency_of_occurrence_", tolower(input$rank), ".csv"),
      content = function(file) utils::write.csv(fo_tbl(), file, row.names = FALSE))
  }

  list(ui = ui, server = server)
}
