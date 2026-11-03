# min_stomachs: covariate panels with too few stomachs are not drawn.

few_prep <- function() {
  # year 2020: 4 stomachs; year 2021: 12 stomachs
  stom <- c(paste0("a", 1:4), paste0("b", 1:12))
  d <- data.frame(pred = "A", stom = rep(stom, each = 2), name = "x",
                  year = rep(c("2020", "2021"), c(8, 24)),
                  phylum = rep(c("P1", "P2"), 16), class = rep(c("C1", NA), 16),
                  w = 1)
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "name", weight = "w",
                  covariates = "year", ranks = c("phylum", "class"))
  dv_prepare(d, spec, taxonomy = "columns", verbose = FALSE)
}

n_panels <- function(d, view, band = "occurrence")
  sum(vapply(d$views[[view]], function(p) p$b == band, TRUE))

test_that("dv_build_html() leaves out covariate panels below min_stomachs", {
  prep <- few_prep()
  msg <- "Too few stomachs to show (minimum: 10)"
  out <- tempfile(fileext = ".html"); on.exit(unlink(out), add = TRUE)

  dv_build_html(prep, output = out, strata = "year", min_stomachs = 10)
  x <- dash_data(out)
  expect_match(x$html, "<h5>year: 2020</h5>", fixed = TRUE)
  expect_match(x$html, "Stomachs (n) = 4", fixed = TRUE)
  expect_match(x$html, msg, fixed = TRUE)
  # aggregated + 2021 only, in every view
  expect_equal(n_panels(x$data, "view_global"), 2L)
  expect_equal(n_panels(x$data, "view_global", "weight"), 2L)
  expect_equal(x$data$views$view_global[[1]]$t, "Aggregated")
  # no subset holds the 4 stomachs of 2020
  n_occ <- vapply(x$data$subsets, function(s) {
    root <- unlist(x$data$nodes$parent)[unlist(s$n) + 1L] == -1L
    sum(unlist(s$o)[root])
  }, 0)
  expect_false(8 %in% n_occ)

  dv_build_html(prep, output = out, strata = "year")   # default 0: all drawn
  x0 <- dash_data(out)
  expect_equal(n_panels(x0$data, "view_global"), 3L)
  expect_false(grepl("Too few stomachs", x0$html, fixed = TRUE))
  expect_true(8 %in% vapply(x0$data$subsets, function(s) {
    root <- unlist(x0$data$nodes$parent)[unlist(s$n) + 1L] == -1L
    sum(unlist(s$o)[root])
  }, 0))
})

test_that("min_stomachs also applies to crossed rows; the aggregate is always drawn", {
  prep <- few_prep()
  prep$data$zone <- "Z"; prep$spec$covariates <- c("year", "zone")
  out <- tempfile(fileext = ".html"); on.exit(unlink(out), add = TRUE)
  dv_build_html(prep, output = out, strata = character(0),
                cross = list(c("year", "zone")), min_stomachs = 10)
  x <- dash_data(out)
  expect_match(x$html, "Too few stomachs to show (minimum: 10)", fixed = TRUE)
  expect_equal(n_panels(x$data, "view_global"), 2L)
  # a threshold above every cell still keeps the aggregated panel
  dv_build_html(prep, output = out, strata = "year", min_stomachs = 100)
  expect_equal(n_panels(dash_data(out)$data, "view_global"), 1L)
  expect_error(dv_build_html(prep, output = out, min_stomachs = -1), "min_stomachs")
  expect_error(dv_build_html(prep, output = out, min_stomachs = c(1, 2)), "min_stomachs")
})

test_that("the app facets and dv_script() follow min_stomachs", {
  prep <- few_prep()
  p <- DietView:::.dv_sunburst_facets(prep$data, prep$ranks, facet_col = "year",
                                      stomach_col = "stom", min_stomachs = 10)
  b <- plotly::plotly_build(p)$x
  ann <- vapply(b$layout$annotations, function(a) a$text, "")
  expect_equal(sum(vapply(b$data, function(t) identical(t$type, "sunburst"), TRUE)), 1L)
  expect_match(ann[1], "year: 2020", fixed = TRUE)
  expect_match(ann[1], "Stomachs (n) = 4", fixed = TRUE)
  expect_match(ann[1], "Too few stomachs to show (minimum: 10)", fixed = TRUE)
  expect_equal(ann[2], "<b>year: 2021</b>")
  p0 <- DietView:::.dv_sunburst_facets(prep$data, prep$ranks, facet_col = "year",
                                       stomach_col = "stom")
  expect_equal(length(plotly::plotly_build(p0)$x$data), 2L)

  skip_if_not_installed("withr")
  dir <- withr::local_tempdir()
  saveRDS(prep, file.path(dir, "dietview_prep.rds"))
  f <- file.path(dir, "s.R")
  s <- dv_script(prep, facet = "year", min_stomachs = 10, file = f)
  expect_true(any(grepl("min_stomachs <- 10", s, fixed = TRUE)))
  env <- new.env()
  withr::with_dir(dir, utils::capture.output(sys.source(f, envir = env)))
  expect_type(env$panels[["2020"]], "character")
  expect_match(env$panels[["2020"]], "Stomachs (n) = 4. Too few stomachs to show (minimum: 10)",
               fixed = TRUE)
  expect_s3_class(env$panels[["2021"]], "plotly")
  # default: the script is unchanged and draws every panel
  expect_false(any(grepl("min_stomachs", dv_script(prep, facet = "year"), fixed = TRUE)))
})
