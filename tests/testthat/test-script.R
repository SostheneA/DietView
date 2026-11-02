ices_prep_small <- function() {
  dat <- ices_diet[ices_diet$predator_common %in% c("Atlantic cod", "Whiting") &
                     ices_diet$item_type != "non_food", ]
  dv_prepare(dat,
             dv_spec(predator = "predator_common", stomach = "stomach_id",
                     prey_id = "prey_aphia_id", prey_name = "prey_name",
                     weight = "prey_weight_g", count = "prey_count",
                     digestion = "digestion_label", covariates = "quarter"),
             taxonomy = "table", lineage = ices_lineage, verbose = FALSE)
}

test_that("dv_script returns a parseable script that records its choices", {
  prep <- ices_prep_small()
  s <- dv_script(prep, predator = "Atlantic cod", mode = "weight",
                 aggregation = list(threshold = 5, scope = "pooled", min_predators = 2),
                 facet = "quarter", rank = "Order")
  expect_s3_class(s, "dietview_script")
  expect_silent(parse(text = s))
  expect_true(any(grepl("dv_aggregate_threshold(prep, threshold = 5, scope = \"pooled\", min_predators = 2)",
                        s, fixed = TRUE)))
  expect_true(any(grepl("dv_rank_table(tree, \"Order\")", s, fixed = TRUE)))
  expect_true(any(grepl("dv_digestion_diagnostic", s)))
  expect_error(dv_script(prep, rank = "tribe"), "rank")
  expect_error(dv_script(prep, facet = c("a", "b", "c")), "at most two")
  expect_error(dv_script(prep, aggregation = list(scope = "pooled")), "threshold")
})

test_that("a generated script runs and rebuilds the same tree", {
  prep <- ices_prep_small()
  dir <- withr::local_tempdir()
  saveRDS(prep, file.path(dir, "dietview_prep.rds"))
  f <- file.path(dir, "analysis.R")
  dv_script(prep, predator = "Whiting", mode = "occurrence",
            aggregation = list(threshold = 4, scope = "per_predator"),
            facet = "quarter", file = f)
  env <- new.env()
  withr::with_dir(dir, utils::capture.output(sys.source(f, envir = env)))
  agg <- dv_aggregate_threshold(prep, threshold = 4, scope = "per_predator")
  agg$data <- agg$data[agg$data$predator_common == "Whiting", ]
  ref <- dv_build_tree(agg$data, agg$ranks, weight_col = "prey_weight_g")
  expect_equal(as.data.frame(env$tree), as.data.frame(ref))
  q <- as.character(agg$data$quarter); q[is.na(q) | q == ""] <- "NA"
  expect_length(env$panels, length(unique(q)))
  # the script colors by node id from the pooled tree of all predators, as the app does
  pooled <- dv_aggregate_threshold(prep, threshold = 4, scope = "per_predator")
  expect_identical(env$pal, dv_palette_tree(dv_build_tree(pooled$data, pooled$ranks)))
})

test_that("two facets give a grid of panels, missing values in an NA panel", {
  prep <- ices_prep_small()
  prep$data$region2 <- ifelse(seq_len(nrow(prep$data)) %% 5 == 0, NA, "A")
  dir <- withr::local_tempdir()
  saveRDS(prep, file.path(dir, "my_prep.rds"))
  f <- file.path(dir, "analysis.R")
  s <- dv_script(prep, facet = c("quarter", "region2"), data_file = "my_prep.rds",
                 file = f)
  expect_true(any(grepl("saveRDS(prep, \"my_prep.rds\")", s, fixed = TRUE)))
  env <- new.env()
  withr::with_dir(dir, utils::capture.output(sys.source(f, envir = env)))
  expect_setequal(names(env$panels), c("A", "NA"))
  expect_s3_class(env$panels[["NA"]][[1]], "plotly")
})

test_that("the app exposes the three aggregation strategies and the script", {
  skip_if_not_installed("shiny")
  prep <- ices_prep_small()
  app <- DietView:::.dv_app(prep)
  shiny::testServer(app$server, {
    session$setInputs(predator = "Atlantic cod", mode = "occurrence", resolution = "none",
                      threshold = 5, min_predators = 2, facet = "(none)",
                      cross = "(none)", rank = "Class")
    expect_null(attr(prep_res(), "aggregation"))
    expect_true(all(prep_sel()$data$predator_common == "Atlantic cod"))

    session$setInputs(resolution = "pooled")
    a1 <- attr(prep_res(), "aggregation")
    expect_equal(a1$scope, "pooled"); expect_equal(a1$min_predators, 1L)

    session$setInputs(resolution = "cross")
    a2 <- attr(prep_res(), "aggregation")
    expect_equal(a2$min_predators, 2L)
    expect_lte(a2$n_categories, a1$n_categories)

    session$setInputs(resolution = "per_predator")
    expect_equal(attr(prep_res(), "aggregation")$scope, "per_predator")
    expect_true(any(grepl("per_predator", script())))
    expect_true(abs(sum(rank_tbl()$pct_occ) - 100) < 1e-6)
    expect_true(all(c("taxon", "pct_fo") %in% names(fo_tbl())))
  })
})
