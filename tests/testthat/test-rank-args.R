# One rank convention: column name or display label, any case, trimmed.

rank_prep <- function() {
  dat <- ices_diet[ices_diet$predator_common %in% c("Atlantic cod", "Whiting") &
                     ices_diet$item_type != "non_food", ]
  dv_prepare(dat,
             dv_spec(predator = "predator_common", stomach = "stomach_id",
                     prey_id = "prey_aphia_id", prey_name = "prey_name",
                     weight = "prey_weight_g", covariates = "quarter"),
             taxonomy = "table", lineage = ices_lineage, verbose = FALSE)
}

test_that(".dv_match_rank() accepts names and labels in any case", {
  r <- c("kingdom", "phylum", "class")
  for (x in c("class", "Class", " CLASS ")) expect_equal(.dv_match_rank(x, r), "class")
  expect_equal(.dv_match_rank("class", c("Kingdom", "Class")), "Class")
  expect_error(.dv_match_rank("tribe", r), "kingdom, phylum, class")
  expect_error(.dv_match_rank(c("class", "phylum"), r), "single rank")
  expect_error(.dv_match_rank(NA, r), "single rank")
})

test_that("every rank argument gives identical results for class, Class, ' CLASS '", {
  prep <- rank_prep()
  tree <- dv_tree(prep)
  variants <- c("class", "Class", " CLASS ")
  same <- function(f) {
    res <- lapply(variants, f)
    expect_identical(res[[1]], res[[2]])
    expect_identical(res[[1]], res[[3]])
    res[[1]]
  }
  rt <- same(function(r) dv_rank_table(tree, r))
  expect_gt(nrow(rt), 0)
  same(function(r) dv_summary(prep, rank = r))
  same(function(r) dv_prey_accumulation(prep, rank = r, permutations = 5, seed = 3))
  same(function(r) dv_fo_table(prep, rank = r))
  same(function(r) dv_matrix(prep, rank = r, currency = "occurrence"))
  same(function(r) {
    s <- dv_script(prep, rank = r)
    unclass(s)[!grepl("^## Generated", s)]
  })
  expect_identical(dv_fo_table(prep, rank = c("Class", "order")),
                   dv_fo_table(prep, rank = c("class", "ORDER")))
})

test_that("an unknown rank is an error that lists the ranks", {
  prep <- rank_prep()
  tree <- dv_tree(prep)
  msg <- "kingdom, phylum, class, order, family, genus, species"
  expect_error(dv_rank_table(tree, "tribe"), "Kingdom, Phylum, Class")
  expect_error(dv_summary(prep, rank = "tribe"), msg)
  expect_error(dv_prey_accumulation(prep, rank = "tribe", permutations = 2), msg)
  expect_error(dv_fo_table(prep, rank = "tribe"), msg)
  expect_error(dv_matrix(prep, rank = "tribe"), msg)
  expect_error(dv_script(prep, rank = "tribe"), msg)
})
