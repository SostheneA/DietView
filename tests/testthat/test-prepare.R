test_that("prey missing from the lineage table are reported", {
  e <- example_data()
  lin <- e$lin[e$lin$verified_name != "Mysida", ]
  expect_warning(dv_prepare(e$dat, example_spec(), taxonomy = "table",
                            lineage = lin, verbose = FALSE), "absent from `lineage`")
})

test_that("validation catches negative weights and shared stomach ids", {
  e <- example_data()
  bad <- e$dat; bad$prey_weight[1] <- -1
  expect_error(dv_validate(bad, example_spec(), quiet = TRUE), "negative")
  sh <- e$dat; sh$stomach_id[sh$predator_species_common_name == "Alewife"] <- "GM001"
  expect_warning(dv_validate(sh, example_spec(), quiet = TRUE), "more than one predator")
})

test_that("strict_covariates = FALSE really drops the missing covariate", {
  e <- example_data()
  prep <- suppressWarnings(dv_prepare(e$dat, example_spec(covariates = c("period", "depth")),
            taxonomy = "table", lineage = e$lin, strict_covariates = FALSE, verbose = FALSE))
  expect_equal(prep$spec$covariates, "period")
})

test_that("bin and period labels say what they contain", {
  expect_equal(levels(dv_size_bins(c(18, 26), breaks = c(0, 20, 30))), c("[0, 20)", "[20, 30)"))
  expect_equal(as.character(dv_size_bins(20, breaks = c(0, 20, 30))), "[20, 30)")
  expect_equal(levels(dv_add_period(c(2004, 2010), breaks = c(2003, 2007, 2020))),
               c("2003-2007", "2008-2020"))
})
