# Direct tests for exported functions and options that had none.

test_that("dv_sunburst() draws a plotly sunburst from a tree or from raw records", {
  prep <- example_prep()
  tree <- dv_tree(prep)
  for (m in c("count", "occurrence", "weight")) {
    p <- dv_sunburst(tree, mode = m, title = "t")
    expect_s3_class(p, "plotly")
  }
  b <- plotly::plotly_build(dv_sunburst(tree))
  expect_equal(b$x$data[[1]]$type, "sunburst")
  expect_equal(length(b$x$data[[1]]$ids), nrow(tree))

  raw <- dv_sunburst(prep$data, ranks = prep$ranks, weight_col = prep$spec$weight)
  expect_s3_class(raw, "plotly")
})

test_that("dv_summary() has one row per predator and accounts for every record", {
  prep <- example_prep()
  s <- dv_summary(prep)
  pcol <- prep$spec$predator
  expect_equal(nrow(s), length(unique(prep$data[[pcol]])))
  expect_equal(sum(s$n_records), nrow(prep$data))
  expect_equal(sum(s$n_stomachs),
               nrow(unique(prep$data[c(pcol, prep$spec$stomach)])))
  expect_equal(s$records_per_stomach, round(s$n_records / s$n_stomachs, 2))
  expect_false(is.unsorted(rev(s$n_stomachs)))
  expect_error(dv_summary(prep, by = "nope"), "`by` column not found")
})

test_that("dv_palette() gives each label one color and the NA category white", {
  cols <- dv_palette(c("A", "B", "A", "NA", NA))
  expect_setequal(names(cols), c("A", "B", "NA"))
  expect_equal(unname(cols["NA"]), "#FFFFFF")
  expect_false(cols["A"] == cols["B"])
  expect_match(cols, "^#[0-9A-Fa-f]{6}$")
})

test_that("dv_palette_tree() colors every node, with descendants tinted from their base", {
  tree <- dv_tree(example_prep())
  cols <- dv_palette_tree(tree)
  expect_equal(names(cols), tree$id)
  expect_match(cols, "^#[0-9A-Fa-f]{6}$")
  expect_true(all(cols[tree$label == "NA"] == "#FFFFFF"))
  # rank-1 nodes (above base_rank = 2) are gray unless unidentified
  top <- tree$id[tree$rank == tree$rank[1] & tree$label != "NA"]
  expect_true(all(cols[top] == "#BDBDBD"))
})

test_that("dv_prey_accumulation() is reproducible, non-decreasing and leaves the RNG alone", {
  prep <- example_prep()
  set.seed(5521)
  before <- .Random.seed
  a1 <- dv_prey_accumulation(prep, permutations = 10, seed = 7)
  expect_identical(.Random.seed, before)
  a2 <- dv_prey_accumulation(prep, permutations = 10, seed = 7)
  expect_identical(a1, a2)
  expect_false(is.unsorted(a1$mean_richness))
  expect_equal(max(a1$n_stomachs),
               length(unique(prep$data[[prep$spec$stomach]])))

  by_pred <- dv_prey_accumulation(prep, by = prep$spec$predator,
                                  permutations = 5, seed = 7)
  expect_true(prep$spec$predator %in% names(by_pred))
})

test_that("dv_threshold_sweep() reports one row per threshold, matching dv_aggregate_threshold()", {
  prep <- example_prep()
  th <- c(1, 3, 10)
  sw <- dv_threshold_sweep(prep, thresholds = th)
  expect_equal(sw$threshold, th)
  for (i in seq_along(th)) {
    a <- dv_aggregate_threshold(prep, th[i])
    expect_equal(sw$n_categories[i], attr(a, "aggregation")$n_categories)
  }
  expect_true(all(sw$pct_coarser >= 0 & sw$pct_coarser <= 100))
})

test_that("per-predator aggregation: every category reaches the threshold within its predator", {
  prep <- example_prep()
  th <- 3
  agg <- dv_aggregate_threshold(prep, th, scope = "per_predator")
  d <- agg$data
  pcol <- prep$spec$predator; scol <- prep$spec$stomach
  oth <- attr(agg, "aggregation")$other_label
  keep <- !is.na(d$prey_category) & d$prey_category != oth
  n_st <- tapply(d[[scol]][keep],
                 paste(d[[pcol]][keep], d$prey_category[keep], sep = "@@"),
                 function(z) length(unique(z)))
  expect_true(all(n_st >= th))
  expect_equal(attr(agg, "aggregation")$scope, "per_predator")
})

test_that("dv_matrix(currency = 'weight') keeps the total weight", {
  prep <- example_prep()
  m <- dv_matrix(prep, currency = "weight")
  w <- suppressWarnings(as.numeric(prep$data[[prep$spec$weight]]))
  expect_equal(sum(m), sum(w, na.rm = TRUE))
  expect_equal(nrow(m), length(unique(prep$data[[prep$spec$stomach]])))
  fo <- dv_matrix(prep, currency = "fo")
  expect_true(all(fo %in% c(0, 1)))
})

test_that("dv_deploy() writes the dashboard into the given directory", {
  prep <- example_prep()
  dir <- file.path(tempfile("dv_deploy_"), "sub")
  on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)
  expect_message(
    path <- dv_deploy(prep, file = "dash.html", dir = dir, strata = character(0),
                      bands = "count", self_contained = FALSE),
    "Deployed")
  expect_true(file.exists(path))
  expect_equal(basename(path), "dash.html")
  expect_match(paste(readLines(path, warn = FALSE), collapse = "\n"), "sunburst")
})

test_that("dv_build_html(self_contained = TRUE) writes one file with no lib folder", {
  prep <- example_prep()
  dir <- tempfile("dv_sc_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  out <- dv_build_html(prep, output = file.path(dir, "dash.html"),
                       strata = character(0), bands = "count",
                       self_contained = TRUE)
  expect_true(file.exists(out))
  expect_equal(list.files(dir), "dash.html")
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_false(grepl("<script src=\"lib/", html, fixed = TRUE))
})

test_that("dv_taxonomy_report() needs a WoRMS log and returns the doubtful rows", {
  expect_error(dv_taxonomy_report(example_prep()), "No taxonomy log")

  skip_if_not_installed("worrms")
  local_worms(
    record = function(id, ...) data.frame(
      AphiaID = id, scientificname = "Pandalus borealis", status = "accepted",
      valid_AphiaID = id, valid_name = "Pandalus borealis"),
    classification = function(id, ...) data.frame(
      rank = c("Kingdom", "Phylum"), scientificname = c("Animalia", "Arthropoda")),
    names = function(name, ...) stop("(204) No Content"),
    taxamatch = function(name, ...) {
      if (name == "Pandalus boreallis")
        list(data.frame(AphiaID = 107649L, scientificname = "Pandalus borealis",
                        status = "accepted", valid_AphiaID = 107649L,
                        valid_name = "Pandalus borealis"))
      else stop("(204) No Content")
    }
  )
  dat <- data.frame(pred = "cod", stom = c("s1", "s2", "s3", "s4"),
                    aphia = c(107649, NA, NA, NA),
                    name = c("Pandalus borealis", "Pandalus boreallis",
                             "Pandalus boreallis", "mystery"))
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_id = "aphia",
                  prey_name = "name")
  prep <- suppressMessages(suppressWarnings(
    dv_prepare(dat, spec, taxonomy = "worms", cache_dir = NULL, verbose = FALSE)))

  rev <- dv_taxonomy_report(prep)
  expect_setequal(rev$match_type, c("fuzzy", "unresolved"))
  expect_equal(rev$n_records[1], 2L)             # sorted by records affected
  expect_equal(nrow(dv_taxonomy_report(prep, "fuzzy")), 1L)
  expect_equal(nrow(dv_taxonomy_report(prep, "all")), 3L)

  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  dv_taxonomy_report(prep, "all", file = f)
  expect_equal(nrow(utils::read.csv(f)), 3L)
})

test_that("print.dietview_prep() describes the object and returns it invisibly", {
  prep <- example_prep()
  expect_output(out <- print(prep), "<dietview_prep>")
  expect_output(print(prep), "records   :")
  expect_output(print(prep), "source    : table")
  expect_identical(out, prep)
})
