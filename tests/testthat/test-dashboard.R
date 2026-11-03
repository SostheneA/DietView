# The dashboard: one JSON block, plotly.js once, sunbursts drawn on demand.

test_that("the dashboard stores each sunburst as data, not as a widget", {
  prep <- example_prep()
  out <- tempfile(fileext = ".html"); on.exit(unlink(out), add = TRUE)
  dv_build_html(prep, output = out, strata = "period")
  x <- dash_data(out)
  # plotly.js is embedded once; no htmlwidgets
  expect_equal(lengths(regmatches(x$html, gregexpr("plotly.js v", x$html, fixed = TRUE))), 1L)
  expect_false(grepl("htmlwidget", x$html, fixed = TRUE))
  expect_false(grepl("<script src=", x$html, fixed = TRUE))
  d <- x$data
  expect_setequal(names(d$bands), c("occurrence", "weight"))
  # every panel has a placeholder div in the page and points to a subset
  divs <- unlist(lapply(d$views, function(v) vapply(v, function(p) p$d, "")))
  expect_true(all(vapply(divs, function(id) grepl(sprintf("id=\"%s\"", id), x$html, fixed = TRUE), TRUE)))
  # a subset reproduces dv_build_tree() of its records
  g <- d$views$view_global[[1]]
  s <- d$subsets[[g$s + 1L]]
  ids <- unlist(d$nodes$id)[unlist(s$n) + 1L]
  ref <- dv_build_tree(prep$data, prep$ranks, weight_col = prep$spec$weight)
  expect_setequal(ids, ref$id)
  expect_equal(unlist(s$o), ref$value_occ[match(ids, ref$id)])
  expect_equal(unlist(s$w), signif(ref$value_w[match(ids, ref$id)], 6))
  # colors follow dv_palette_tree() of the pooled tree
  pal <- dv_palette_tree(ref)
  expect_equal(unlist(d$nodes$color), unname(pal[unlist(d$nodes$id)]))
  # bands share one subset per set of records
  occ <- vapply(d$views$view_global, function(p) p$b == "occurrence", TRUE)
  expect_equal(vapply(d$views$view_global[occ], function(p) p$s, 0),
               vapply(d$views$view_global[!occ], function(p) p$s, 0))
})

test_that("cards are keyboard-accessible buttons", {
  prep <- example_prep()
  out <- tempfile(fileext = ".html"); on.exit(unlink(out), add = TRUE)
  dv_build_html(prep, output = out, strata = character(0), bands = "count")
  html <- dash_data(out)$html
  n_cards <- lengths(regmatches(html, gregexpr("class=\"species-card\"", html)))
  expect_equal(lengths(regmatches(html, gregexpr("role=\"button\" tabindex=\"0\"", html))), n_cards)
  expect_match(html, "cardKey(event,&#39;view_global&#39;)", fixed = TRUE)
  expect_match(html, "function cardKey", fixed = TRUE)
})

test_that("self_contained = FALSE links plotly.js from a lib folder", {
  prep <- example_prep()
  dir <- tempfile("dv_lib_"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  out <- dv_build_html(prep, output = file.path(dir, "d.html"), strata = character(0),
                       self_contained = FALSE)
  expect_true(file.exists(file.path(dir, "lib", "plotlyjs", "plotly-latest.min.js")))
  expect_match(paste(readLines(out, warn = FALSE), collapse = "\n"),
               "<script src=\"lib/plotlyjs/plotly-latest.min.js\">", fixed = TRUE)
  expect_lt(file.size(out), 1e6)
})
