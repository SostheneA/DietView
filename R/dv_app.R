#' Launch the interactive DietView app
#'
#' A Shiny explorer over a prepared dataset: pick a predator (or
#' "(all predators)" to pool every predator together), a mode (occurrence
#' counts / occurrence % / weight %), and optionally one covariate to facet by
#' plus a second one to cross it with (e.g. length bins by period). Shows the
#' sunburst -- one panel per covariate cell when faceting -- plus the
#' within-rank importance table for the current selection.
#'
#' @param prep A `dietview_prep` from [dv_prepare()].
#' @param ... Passed to [shiny::runApp()].
#' @return Runs the app (does not return).
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
#' if (interactive()) {
#'   run_dietview(prep)
#' }
#' @export
run_dietview <- function(prep, ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Install 'shiny' to run the app.", call. = FALSE)
  }
  stopifnot(inherits(prep, "dietview_prep"))
  spec <- prep$spec; d <- prep$data; ranks <- prep$ranks
  colors <- dv_palette(unlist(lapply(ranks, function(r) .dv_fill_na(d[[r]]))))
  ALL_PRED <- "(all predators)"
  preds <- c(ALL_PRED, sort(unique(as.character(d[[spec$predator]]))))
  covs <- c("(none)", spec$covariates)

  ui <- shiny::fluidPage(
    shiny::titlePanel("DietView"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::selectInput("predator", "Predator", choices = preds),
        shiny::radioButtons("mode", "Mode",
                            c("Occurrence counts" = "count",
                              "Occurrence %" = "occurrence",
                              "Weight %" = "weight")),
        shiny::selectInput("facet", "Facet by covariate", choices = covs),
        shiny::selectInput("cross", "Cross with (second covariate)",
                           choices = covs),
        shiny::selectInput("rank", "Importance table rank",
                           choices = .dv_titlecase(ranks), selected = "Class")
      ),
      shiny::mainPanel(
        plotly::plotlyOutput("sunburst", height = "600px"),
        shiny::h4("Within-rank importance"),
        if (requireNamespace("DT", quietly = TRUE)) DT::DTOutput("tbl") else shiny::tableOutput("tbl")
      )
    )
  )

  server <- function(input, output, session) {
    recs <- shiny::reactive({
      if (identical(input$predator, ALL_PRED)) d
      else d[which(as.character(d[[spec$predator]]) == input$predator), ]
    })
    tree <- shiny::reactive(
      dv_build_tree(recs(), ranks = ranks, weight_col = spec$weight, count_col = spec$count)
    )
    output$sunburst <- plotly::renderPlotly({
      if (identical(input$facet, "(none)")) {
        dv_sunburst(tree(), mode = input$mode, colors = colors,
                    title = input$predator)
      } else {
        fc <- input$facet
        if (!identical(input$cross, "(none)") &&
            !identical(input$cross, input$facet)) {
          fc <- c(input$facet, input$cross)   # c(inner, outer)
        }
        .dv_sunburst_facets(
          recs(), ranks = ranks,
          weight_col = spec$weight, count_col = spec$count,
          facet_col = fc, mode = input$mode, colors = colors,
          title = paste0(input$predator, " - ",
                         if (length(fc) == 2L)
                           paste(fc[1], "by", fc[2])
                         else paste("faceted by", fc))
        )
      }
    })
    render_tbl <- function() dv_rank_table(tree(), input$rank)
    if (requireNamespace("DT", quietly = TRUE)) {
      output$tbl <- DT::renderDT(render_tbl(), options = list(pageLength = 15))
    } else {
      output$tbl <- shiny::renderTable(render_tbl())
    }
  }

  shiny::runApp(shiny::shinyApp(ui, server), ...)
}
