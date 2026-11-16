# Focused scientific-invariant regression tests. All tests run offline.

local_prep <- function(data, ranks = c("phylum", "class"), count = NULL) {
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "prey",
                  weight = "weight", count = count, ranks = ranks)
  dv_prepare(data, spec, taxonomy = "columns", verbose = FALSE)
}

test_that("missing or blank sampling-unit identifiers never disappear silently", {
  d <- data.frame(pred = "cod", stom = c("s1", NA), prey = "shrimp",
                  weight = 1, phylum = "Arthropoda", class = "Malacostraca")
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "prey",
                  weight = "weight", ranks = c("phylum", "class"))
  expect_error(dv_validate(d, spec), "missing or blank")
  d$stom[2] <- "   "
  expect_error(dv_prepare(d, spec, taxonomy = "columns", verbose = FALSE),
               "missing or blank")
  d$stom[2] <- "s2"
  st <- data.frame(stom = c("s1", " "), pred = "cod")
  expect_error(dv_prepare(d, spec, taxonomy = "columns", stomachs = st,
                          verbose = FALSE), "missing or blank")
})

test_that("weight and count cannot be negative or infinite", {
  d <- data.frame(pred = "cod", stom = "s1", prey = "shrimp", weight = 2,
                  n = 3, phylum = "Arthropoda", class = "Malacostraca")
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "prey",
                  weight = "weight", count = "n", ranks = c("phylum", "class"))
  d$n <- -1
  expect_error(dv_validate(d, spec), "negative count")
  d$n <- Inf
  expect_error(dv_validate(d, spec), "finite")
  d$n <- 1.5
  expect_warning(dv_validate(d, spec, quiet = TRUE), "not whole numbers")
  d$n <- 3
  d$weight <- Inf
  expect_error(dv_validate(d, spec), "finite")
})

test_that("wide-table collapse retains NA taxonomy groups and conserves reads", {
  x <- data.frame(asv = c("A", "B", "C"), tax = c("x", NA, NA),
                  S1 = c(10, 5, 7), S2 = c(0, 3, 2))
  long <- dv_from_wide(x, id_cols = c("asv", "tax"), collapse_by = "tax")
  expect_equal(sum(long$reads), 27)
  expect_equal(long$reads[long$sample == "S1" & is.na(long$tax)], 12)
  expect_equal(long$reads[long$sample == "S2" & is.na(long$tax)], 5)
  expect_error(dv_from_wide(x, id_cols = c("asv", "tax"),
                            collapse_by = "reads"), "cannot contain")
})

test_that("empty matrices are valid and unknown category errors are clear", {
  d <- data.frame(pred = "cod", stom = c("s1", "s2"), prey = "unknown",
                  weight = c(1, 2), phylum = NA_character_, class = NA_character_)
  prep <- local_prep(d)
  m <- dv_matrix(prep, include_na = FALSE, currency = "occurrence")
  expect_true(is.matrix(m))
  expect_equal(dim(m), c(0L, 0L))
  expect_error(dv_matrix(prep, category = "absent"), "category.*not found")
})

test_that("accumulation and aggregation reject invalid numerical parameters", {
  d <- data.frame(pred = "cod", stom = c("s1", "s2"), prey = "shrimp",
                  weight = 1, phylum = "Arthropoda", class = "Malacostraca")
  prep <- local_prep(d)
  expect_error(dv_prey_accumulation(prep, permutations = 0), "positive whole")
  expect_error(dv_prey_accumulation(prep, permutations = 1.5), "positive whole")
  expect_error(dv_aggregate_threshold(prep, threshold = Inf), "finite")
  expect_error(dv_aggregate_threshold(prep, threshold = 1,
                                      min_predators = NA_real_), "positive whole")
})

test_that("homonymous labels are distinct for matrices, richness, FO and aggregation", {
  d <- data.frame(pred = "cod", stom = c("s1", "s2", "s3", "s4"),
                  prey = c("A", "A", "B", "B"), weight = c(1, 2, 3, 4),
                  phylum = c("P1", "P1", "P2", "P2"), class = "Shared")
  prep <- local_prep(d)
  m <- dv_matrix(prep, rank = "class", currency = "occurrence")
  expect_equal(dim(m), c(4L, 2L))
  expect_equal(sum(m), 4)
  expect_equal(dv_summary(prep, rank = "class")$n_taxa, 2L)
  fo <- dv_fo_table(prep, rank = "class")
  expect_equal(length(unique(fo$taxon)), 2L)
  agg <- dv_aggregate_threshold(prep, threshold = 2)
  expect_equal(attr(agg, "aggregation")$n_categories, 2L)
  expect_equal(length(unique(agg$data$prey_category)), 1L) # display labels unchanged
  expect_equal(length(unique(agg$data$prey_category_id)), 2L)
  ma <- dv_matrix(agg, currency = "occurrence")
  expect_equal(dim(ma), c(4L, 2L))
  expect_equal(sum(ma), 4)
  stable <- dv_matrix(agg, category = "prey_category_id", currency = "occurrence")
  expect_equal(ncol(stable), 2L)
})

test_that("weight and occurrence conservation survives different taxon depths", {
  d <- data.frame(pred = "cod", stom = paste0("s", 1:6),
                  prey = letters[1:6], weight = c(1, 2, 0, 3, 4, 5),
                  phylum = c("A", "A", "B", "B", "B", NA),
                  class = c("a", NA, "b", "b", NA, NA))
  prep <- local_prep(d)
  tree <- dv_tree(prep)
  for (rank in unique(tree$rank)) {
    ix <- tree$rank == rank
    expect_equal(sum(tree$value_occ[ix]), nrow(d))
    expect_equal(sum(tree$value_w[ix]), sum(d$weight))
    expect_equal(sum(tree$pct_occ[ix]), 100)
    expect_equal(sum(tree$pct_w[ix]), 100)
  }
  expect_equal(sum(dv_matrix(prep, currency = "weight")), sum(d$weight))
  expect_equal(sum(dv_matrix(prep, currency = "occurrence")), nrow(d))
})
