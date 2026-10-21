test_that("the bundled example gives the expected class shares", {
  prep <- example_prep()
  tree <- dv_build_tree(prep$data, prep$ranks, weight_col = "prey_weight")
  cls  <- dv_rank_table(tree, "Class")
  expect_equal(sum(cls$value_occ), 24)
  expect_equal(cls$value_occ[cls$label == "Malacostraca"], 11)
  expect_equal(round(cls$pct_occ[cls$label == "Malacostraca"], 2), 45.83)
  # the fish class is read from the lineage ("Teleostei" now, "Actinopteri" after a
  # WoRMS regeneration), so the test survives that change
  fish <- example_data()$lin$class[example_data()$lin$verified_name == "Ammodytes dubius"]
  expect_length(cls$pct_w[cls$label == fish], 1)
  expect_equal(round(cls$pct_w[cls$label == fish], 1), 45.5)
})

test_that("every rank has the same denominator: all records, all weight", {
  prep <- example_prep()
  tree <- dv_build_tree(prep$data, prep$ranks, weight_col = "prey_weight")
  expect_true(all(tapply(tree$value_occ, tree$rank, sum) == nrow(prep$data)))
  w <- sum(prep$data$prey_weight, na.rm = TRUE)
  expect_true(all(abs(tapply(tree$value_w, tree$rank, sum) - w) < 1e-9))
})

test_that("a parent equals the sum of its children at every rank", {
  prep <- example_prep()
  tree <- dv_build_tree(prep$data, prep$ranks, weight_col = "prey_weight")
  kids <- tapply(tree$value_occ, tree$parent, sum)
  par  <- intersect(tree$id, names(kids))
  expect_equal(unname(tree$value_occ[match(par, tree$id)]), unname(as.numeric(kids[par])))
})

test_that("a count column turns records into numbers", {
  prep <- example_prep()
  tn <- dv_build_tree(prep$data, prep$ranks, count_col = "number_of_prey")
  expect_equal(sum(tn$value_occ[tn$rank == "Kingdom"]),
               sum(prep$data$number_of_prey, na.rm = TRUE))   # 286
})
