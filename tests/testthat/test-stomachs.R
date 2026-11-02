# Examined stomachs (empty ones included): vacuity, %FO denominator, empty rows.

st_data <- function() {
  d <- data.frame(pred = c("A", "A", "A", "B"), stom = c("s1", "s1", "s2", "s9"),
                  name = "x", reg = c("N", "N", "S", "N"),
                  phylum = c("P1", "P2", "P1", "P1"), w = c(1, 2, 3, 4))
  st <- data.frame(stom = c("s1", "s2", "s3", "s4", "s5", "s9", "s10", "z1"),
                   pred = c("A", "A", "A", "A", "A", "B", "B", "C"),
                   reg  = c("N", "S", "N", "S", "N", "N", "N", "N"),
                   empty = c(0, 0, 1, 1, NA, 0, 1, 1))
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "name",
                  weight = "w", covariates = "reg", ranks = "phylum")
  list(d = d, st = st, spec = spec)
}

test_that("without a stomach table nothing changes and the new options say why", {
  x <- st_data()
  prep <- dv_prepare(x$d, x$spec, taxonomy = "columns", verbose = FALSE)
  expect_null(prep$stomachs)
  expect_false("pct_vacuity" %in% names(dv_summary(prep)))
  expect_error(dv_fo_table(prep, denominator = "examined"), "stomachs = ")
  expect_error(dv_matrix(prep, include_empty = TRUE), "stomachs = ")
  expect_error(dv_prepare(x$d, x$spec, taxonomy = "columns", empty_col = "empty",
                          verbose = FALSE), "needs `stomachs`")
})

test_that("vacuity counts flagged empty stomachs; unknown ones are left out", {
  x <- st_data()
  prep <- dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st,
                     empty_col = "empty", verbose = FALSE)
  s <- dv_summary(prep)
  a <- s[s$pred == "A", ]
  # A: s1, s2 with records; s3, s4 flagged empty; s5 unknown (no flag)
  expect_equal(c(a$n_stomachs, a$n_examined, a$n_empty), c(2L, 4L, 2L))
  expect_equal(a$pct_vacuity, 50)
  b <- s[s$pred == "B", ]
  expect_equal(c(b$n_examined, b$n_empty), c(2L, 1L))
  # predator C has no records: its stomachs are ignored
  st <- DietView:::.dv_stomach_status(prep)
  expect_false("z1" %in% st$stom)
  expect_equal(st$status[st$stom == "s5"], "unknown")
  # by a covariate present in the stomach table
  sr <- dv_summary(prep, by = "reg")
  expect_equal(sr$n_examined[sr$pred == "A" & sr$reg == "N"], 2L)   # s1, s3
  expect_equal(sr$n_empty[sr$pred == "A" & sr$reg == "S"], 1L)      # s4
})

test_that("without an empty flag every stomach without records is empty", {
  x <- st_data()
  prep <- dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st[, 1:3],
                     verbose = FALSE)
  a <- dv_summary(prep)
  expect_equal(a$n_empty[a$pred == "A"], 3L)                         # s3, s4, s5
})

test_that("%FO can use every examined stomach as the denominator", {
  x <- st_data()
  prep <- dv_prepare(x$d[x$d$pred == "A", ], x$spec, taxonomy = "columns",
                     stomachs = x$st, empty_col = "empty", verbose = FALSE)
  ne <- dv_fo_table(prep, rank = "phylum")
  ex <- dv_fo_table(prep, rank = "phylum", denominator = "examined")
  expect_equal(unique(ne$n_total), 2L)
  expect_equal(unique(ex$n_total), 4L)
  expect_equal(ex$pct_fo[ex$taxon == "P1"], 50)                      # 2 of 4
  expect_equal(ne$pct_fo[ne$taxon == "P1"], 100)
  exr <- dv_fo_table(prep, rank = "phylum", by = "reg", denominator = "examined")
  expect_equal(exr$n_total[exr$reg == "N"][1], 2L)
  prep2 <- dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st[, c("stom", "pred")],
                      verbose = FALSE)
  expect_error(dv_fo_table(prep2, by = "reg", denominator = "examined"), "`reg`")
})

test_that("dv_matrix(include_empty = TRUE) adds zero rows for empty stomachs only", {
  x <- st_data()
  prep <- dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st,
                     empty_col = "empty", verbose = FALSE)
  m0 <- dv_matrix(prep, currency = "occurrence")
  m1 <- dv_matrix(prep, currency = "occurrence", include_empty = TRUE)
  expect_setequal(rownames(m1), c(rownames(m0), "s3", "s4", "s10"))
  expect_true(all(m1[c("s3", "s4", "s10"), ] == 0))
  expect_equal(m1[rownames(m0), ], m0)
  expect_error(dv_matrix(prep, unit = "reg", include_empty = TRUE), "stomach as the unit")
})

test_that("bad stomach tables are refused", {
  x <- st_data()
  expect_error(dv_prepare(x$d, x$spec, taxonomy = "columns",
                          stomachs = x$st[, -1], verbose = FALSE), "stomach column")
  expect_error(dv_prepare(x$d, x$spec, taxonomy = "columns",
                          stomachs = rbind(x$st, x$st[1, ]), verbose = FALSE), "duplicated")
  expect_error(dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = x$st,
                          empty_col = "nope", verbose = FALSE), "not a column")
  st <- x$st; st$empty[1] <- 1
  expect_warning(dv_prepare(x$d, x$spec, taxonomy = "columns", stomachs = st,
                            empty_col = "empty", verbose = FALSE), "flagged empty have prey")
  expect_warning(dv_prepare(x$d, x$spec, taxonomy = "columns",
                            stomachs = x$st[, c("stom", "reg")], verbose = FALSE),
                 "no predator column")
})

test_that("ices_stomachs gives the vacuity of the ICES predators", {
  phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
  dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
  cod <- dat[dat$predator_common == "Atlantic cod", ]
  spec <- dv_spec(predator = "predator_common", stomach = "stomach_id",
                  prey_id = "prey_aphia_id", covariates = "region")
  prep <- suppressWarnings(dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                                      stomachs = ices_stomachs, empty_col = "stomach_empty",
                                      verbose = FALSE))
  s <- dv_summary(prep)
  st <- ices_stomachs[ices_stomachs$predator_common == "Atlantic cod", ]
  n_empty <- sum(st$stomach_empty %in% 1 & !st$stomach_id %in% cod$stomach_id)
  expect_equal(s$n_empty, n_empty)
  expect_equal(s$n_examined, length(unique(cod$stomach_id)) + n_empty)
  m <- dv_matrix(prep, rank = "class", currency = "fo", include_empty = TRUE)
  expect_equal(nrow(m), s$n_examined)
})
