test_that("frequency of occurrence counts stomachs, not records", {
  fo <- dv_fo_table(example_prep(), rank = "class")
  expect_equal(fo$n_stomachs[fo$taxon == "Malacostraca"], 7L)
  expect_equal(unique(fo$n_total), 11L)
})

test_that("digestion shares sum to 100 within each level", {
  dg <- dv_digestion_diagnostic(example_prep())
  expect_true(all(abs(tapply(dg$p_records, dg$digestion, sum) - 100) < 1e-9))
  expect_true(all(dg$finest_rank[dg$digestion == 5] == "Unresolved"))
})

test_that("every reported category reaches the threshold (needs fix P9)", {
  d <- dv_aggregate_threshold(example_prep(), threshold = 3)$data
  keep <- !is.na(d$prey_category) & !startsWith(d$prey_category, "other")
  n_st <- tapply(d$stomach_id[keep], d$prey_category[keep], function(z) length(unique(z)))
  expect_true(all(n_st >= 3))
})

test_that("the stomach x category matrix keeps every record", {
  m <- dv_matrix(example_prep(), currency = "occurrence")
  expect_equal(nrow(m), 11L)
  expect_equal(sum(m), 24)
})
