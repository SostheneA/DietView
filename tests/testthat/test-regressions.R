# Edge cases: absent or factor columns, WoRMS lookups, threshold aggregation.

# --- a declared weight / count column absent from the data -----------

test_that("a declared weight column absent from the data is dropped, not fatal", {
  e <- example_data()
  spec <- example_spec()
  spec$weight <- "no_such_column"
  expect_warning(
    prep <- dv_prepare(e$dat, spec, taxonomy = "table", lineage = e$lin,
                       verbose = FALSE),
    "weight column `no_such_column` is absent")
  expect_null(prep$spec$weight)

  tree <- dv_tree(prep)
  expect_s3_class(tree, "dietview_tree")
  expect_true(all(tree$value_w == 0))
  expect_s3_class(dv_sunburst(tree, mode = "weight"), "plotly")
  expect_s3_class(dv_digestion_diagnostic(prep), "data.frame")
})

test_that("dv_build_tree() warns on an absent weight column and stops on an absent count column", {
  df <- data.frame(phylum = c("A", "B"), class = c("a", NA))
  expect_warning(tree <- dv_build_tree(df, c("phylum", "class"), weight_col = "w"),
                 "not in the data")
  expect_equal(sum(tree$value_occ[tree$rank == "Phylum"]), 2)
  expect_error(dv_build_tree(df, c("phylum", "class"), count_col = "n"),
               "count column `n` is not in the data")
})

test_that("a declared count column absent from the data gives a clear error for numbers", {
  e <- example_data()
  spec <- example_spec(count = "no_such_count")
  prep <- suppressWarnings(dv_prepare(e$dat, spec, taxonomy = "table",
                                      lineage = e$lin, verbose = FALSE))
  expect_null(prep$spec$count)
  expect_error(dv_tree(prep, currency = "numbers"), "needs `count`")
  expect_s3_class(dv_tree(prep), "dietview_tree")
})

test_that("dv_digestion_diagnostic() rejects an unknown `by` column", {
  expect_error(dv_digestion_diagnostic(example_prep(), by = "nope"),
               "`by` column not found")
})

# --- factor columns are read by their values -------------------------

test_that("factor weight and count columns are read by value, not by level code", {
  df <- data.frame(phylum = c("A", "A", "B"),
                   w = factor(c("10", "2.5", "100")),
                   n = factor(c("3", "1", "20")))
  tree <- dv_build_tree(df, "phylum", weight_col = "w", count_col = "n")
  expect_equal(tree$value_w[tree$label == "A"], 12.5)
  expect_equal(tree$value_w[tree$label == "B"], 100)
  expect_equal(tree$value_occ[tree$label == "B"], 20)
})

test_that("a factor weight gives the same totals as a numeric one everywhere", {
  e <- example_data()
  ref <- example_prep()
  dat_f <- e$dat
  dat_f$prey_weight <- factor(dat_f$prey_weight)
  prep_f <- suppressMessages(dv_prepare(dat_f, example_spec(), taxonomy = "table",
                                        lineage = e$lin, verbose = FALSE))
  expect_equal(sum(dv_tree(prep_f)$value_w), sum(dv_tree(ref)$value_w))
  expect_equal(dv_summary(prep_f)$total_weight, dv_summary(ref)$total_weight)
  expect_equal(sum(dv_matrix(prep_f, currency = "weight")),
               sum(dv_matrix(ref, currency = "weight")))
  expect_equal(sum(dv_digestion_diagnostic(prep_f)$weight),
               sum(dv_digestion_diagnostic(ref)$weight))
})

# --- WoRMS name cache and failed name lookups -------------------

mock_classification <- function(id, ...)
  data.frame(rank = c("Kingdom", "Phylum", "Class", "Order", "Family"),
             scientificname = c("Animalia", "Arthropoda", "Malacostraca",
                                "Decapoda", "Crangonidae"))

test_that("the WoRMS name cache keeps marine_only = TRUE and FALSE apart", {
  skip_if_not_installed("worrms")
  skip_if_not_installed("withr")
  local_mocked_bindings(
    wm_classification = mock_classification,
    # the name is only known when non-marine records are allowed
    wm_records_names = function(name, marine_only = TRUE, ...) {
      if (isTRUE(marine_only)) stop("(204) No Content - AphiaRecordsByNames")
      list(data.frame(AphiaID = 999001L, scientificname = "Crangonidae",
                      status = "accepted", valid_AphiaID = 999001L,
                      valid_name = "Crangonidae"))
    },
    wm_records_taxamatch = function(name, ...)
      stop("(204) No Content - AphiaRecordsByMatchNames"),
    .package = "worrms"
  )
  dir  <- withr::local_tempdir()
  keys <- data.frame(prey_id = NA_integer_, prey_name = "Crangonidae")
  run  <- function(mo) suppressMessages(
    dv_taxonomy_worms(keys, cache_dir = dir, marine_only = mo, verbose = FALSE))

  expect_equal(run(FALSE)$match_type, "exact")
  marine <- run(TRUE)                       # must not reuse the FALSE answer
  expect_equal(marine$match_type, "unresolved")
  expect_true(is.na(marine$family))
})

test_that("a failed WoRMS name lookup is reported, a genuine non-match is not", {
  skip_if_not_installed("worrms")
  calls <- 0L
  local_mocked_bindings(
    wm_classification = mock_classification,
    wm_records_names = function(name, ...) {
      calls <<- calls + 1L
      if (name == "Timeout name") stop("Timeout was reached")
      stop("(204) No Content - AphiaRecordsByNames")
    },
    wm_records_taxamatch = function(name, ...)
      stop("(204) No Content - AphiaRecordsByMatchNames"),
    .package = "worrms"
  )
  keys <- data.frame(prey_id = c(NA_integer_, NA_integer_),
                     prey_name = c("Timeout name", "Unknown name"))
  expect_warning(
    out <- dv_taxonomy_worms(keys, cache_dir = NULL, verbose = FALSE),
    "1 prey name\\(s\\) could not be looked up")
  expect_equal(out$match_type, c("unresolved", "unresolved"))
  expect_equal(out$lineage_ok, c(FALSE, NA))
  # the failure shows up in the review list, the genuine non-match too
  expect_equal(nrow(DietView:::.dv_review_rows(out)), 2L)
})

# --- dv_aggregate_threshold() ----------------------------------------

agg_prep <- function(df) {
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "name",
                  ranks = c("phylum", "class", "order"))
  suppressMessages(dv_prepare(df, spec, taxonomy = "columns", verbose = FALSE))
}

test_that("a rank missing in the middle of a lineage does not prune finer ranks", {
  # Priapulida have no class in WoRMS
  df <- data.frame(pred = "cod", stom = paste0("s", 1:3), name = "Priapulus",
                   phylum = "Priapulida", class = NA_character_,
                   order = "Priapulimorphida")
  agg <- dv_aggregate_threshold(agg_prep(df), threshold = 2)
  expect_equal(agg$data$prey_rank, rep("order", 3))
  expect_equal(agg$data$prey_category, rep("Priapulimorphida", 3))
  expect_equal(agg$data$order, rep("Priapulimorphida", 3))
  expect_true(all(is.na(agg$data$class)))
})

test_that("a gap record that fails the threshold moves up past the empty rank", {
  df <- data.frame(pred = "cod", stom = paste0("s", 1:3), name = "x",
                   phylum = "Priapulida", class = NA_character_,
                   order = c("Priapulimorphida", "Priapulimorphida", "Other"))
  agg <- dv_aggregate_threshold(agg_prep(df), threshold = 3)
  expect_equal(agg$data$prey_rank, rep("phylum", 3))
  expect_equal(agg$data$prey_category, rep("Priapulida", 3))
})

test_that("per-predator '(other)' labels depend only on that predator's records", {
  df <- data.frame(
    pred  = c("A", "A", "A", "A", "B", "B"),
    stom  = c("a1", "a2", "a3", "a4", "b1", "b2"),
    name  = "x",
    phylum = "Arthropoda", class = "Malacostraca",
    order = c("Decapoda", "Decapoda", NA, NA, NA, NA))
  agg <- dv_aggregate_threshold(agg_prep(df), threshold = 2, scope = "per_predator")
  cat_A <- agg$data$prey_category[agg$data$pred == "A"]
  cat_B <- agg$data$prey_category[agg$data$pred == "B"]
  expect_equal(cat_A, c("Decapoda", "Decapoda",
                        "Malacostraca (other)", "Malacostraca (other)"))
  # B kept no order, so its class is a plain category, not "(other)"
  expect_equal(cat_B, c("Malacostraca", "Malacostraca"))
})

test_that("an NA threshold gives a clear error", {
  expect_error(dv_aggregate_threshold(example_prep(), threshold = NA_real_),
               "single number >= 1")
})
