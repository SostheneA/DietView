# dv_prepare(stomachs = ): records missing from the table, predator mismatches.

chk_data <- function() {
  d <- data.frame(pred = c("A", "A", "A", "B", "B", "B", "A"),
                  stom = c("s1", "s1", "s2", "s3", "s4", "s5", "s6"),
                  phylum = "P1", name = "x")
  st <- data.frame(stom = c("s1", "s2", "s3", "s7"),
                   pred = c("A", "A", "B", "A"))
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "name",
                  ranks = "phylum")
  list(d = d, st = st, spec = spec)
}

test_that("stomachs with records but absent from `stomachs` warn once", {
  x <- chk_data()
  w <- testthat::capture_warnings(
    prep <- dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st, verbose = FALSE))
  expect_length(w, 1L)
  expect_match(w, "^3 stomach\\(s\\) have prey records but are absent from `stomachs`")
  expect_match(w, "(e.g. s4, s5, s6)", fixed = TRUE)
  expect_match(w, "counted as examined and non-empty", fixed = TRUE)
  st <- DietView:::.dv_stomach_status(prep)
  expect_equal(st$status[st$stom %in% c("s4", "s5", "s6")], rep("with_records", 3))
})

test_that("a predator mismatch warns once and the records' predator is used", {
  x <- chk_data()
  x$d <- x$d[x$d$stom %in% x$st$stom, ]
  x$st$pred[x$st$stom %in% c("s2", "s3")] <- c("B", "A")
  w <- testthat::capture_warnings(
    prep <- dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st, verbose = FALSE))
  expect_length(w, 1L)
  expect_match(w, "^2 stomach\\(s\\) have a different predator in `stomachs` than in the records")
  expect_match(w, "(e.g. s2, s3)", fixed = TRUE)
  expect_match(w, "the predator of the records is used", fixed = TRUE)
  expect_equal(prep$stomachs$pred[match(c("s2", "s3"), prep$stomachs$stom)], c("A", "B"))
  s <- dv_summary(prep)
  expect_equal(s$n_examined[s$pred == "A"], 3L)   # s1, s2, s7 (empty)
  expect_equal(s$n_examined[s$pred == "B"], 1L)   # s3
})

test_that("examples are capped at three ids and no check runs without a predator column", {
  x <- chk_data()
  d <- rbind(x$d, data.frame(pred = "A", stom = paste0("x", 1:5), phylum = "P1", name = "x"))
  w <- testthat::capture_warnings(
    dv_prepare(d, x$spec, taxonomy = "columns", stomachs = x$st, verbose = FALSE))
  expect_match(w, "^8 stomach", all = FALSE)
  expect_match(w, "(e.g. s4, s5, s6)", fixed = TRUE, all = FALSE)
  w2 <- testthat::capture_warnings(
    dv_prepare(x$d[x$d$stom %in% x$st$stom, ], x$spec, taxonomy = "columns",
               stomachs = x$st[, "stom", drop = FALSE], verbose = FALSE))
  expect_false(any(grepl("different predator", w2)))
})

test_that("ices_diet + ices_stomachs with the standard filter raise no warning", {
  phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
  dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
  spec <- dv_spec(predator = "predator_common", predator_latin = "predator_latin",
                  stomach = "stomach_id", prey_id = "prey_aphia_id",
                  prey_name = "prey_name", weight = "prey_weight_g",
                  count = "prey_count", digestion = "digestion_label",
                  covariates = c("region", "year", "quarter"))
  expect_no_warning(
    dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
               stomachs = ices_stomachs, empty_col = "stomach_empty", verbose = FALSE))
})
