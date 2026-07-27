test_that("within-rank percentages sum to 100 including NA", {
  df <- data.frame(
    phylum  = c("Arthropoda", "Arthropoda", "Chordata", NA),
    class   = c("Malacostraca", NA, "Teleostei", NA),
    order   = c("Decapoda", NA, NA, NA),
    family  = NA, genus = NA, species = NA,
    w = c(10, 5, 20, 3),
    stringsAsFactors = FALSE
  )
  ranks <- c("phylum", "class", "order", "family", "genus", "species")
  tree <- dv_build_tree(df, ranks, weight_col = "w")

  # Each rank's occurrence and weight shares sum to 100
  agg <- tapply(tree$pct_occ, tree$rank, sum)
  expect_true(all(abs(agg - 100) < 1e-6))
  aggw <- tapply(tree$pct_w, tree$rank, sum)
  expect_true(all(abs(aggw - 100) < 1e-6))

  # NA is an explicit node, not dropped
  expect_true(any(tree$label == "NA"))

  # branchvalues='total' invariant: parent occ == sum of children occ
  phyl <- tree[tree$rank == "Phylum", ]
  child <- tree[tree$rank == "Class", ]
  for (id in phyl$id) {
    kids <- child[child$parent == id, ]
    expect_equal(sum(kids$value_occ), phyl$value_occ[phyl$id == id])
  }
})

test_that("empty input yields an empty tree, not an error", {
  df <- data.frame(phylum = character(0), class = character(0),
                   order = character(0), family = character(0),
                   genus = character(0), species = character(0))
  tree <- dv_build_tree(df, c("phylum","class","order","family","genus","species"))
  expect_s3_class(tree, "dietview_tree")
  expect_equal(nrow(tree), 0)
})
