# Smaller edge cases, and WoRMS cache management.

test_that("dv_size_bins() keeps a length equal to the outer break", {
  b <- dv_size_bins(c(0, 20, 30), breaks = c(0, 20, 30))
  expect_false(anyNA(b))
  expect_equal(as.character(b), c("[0, 20)", "[20, 30]", "[20, 30]"))
  r <- dv_size_bins(c(0, 20, 30), breaks = c(0, 20, 30), right = TRUE)
  expect_false(anyNA(r))
  expect_equal(levels(r), c("[0, 20]", "(20, 30]"))
  expect_equal(as.character(r), c("[0, 20]", "[0, 20]", "(20, 30]"))
  expect_true(is.na(dv_size_bins(31, breaks = c(0, 20, 30))))
})

test_that("predators whose names reduce to the same id get distinct dashboard tabs", {
  df <- data.frame(pred = c("A-b", "A b", NA), stom = c("s1", "s2", "s3"),
                   name = "x", phylum = c("P1", "P2", "P1"))
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_name = "name",
                  ranks = "phylum")
  prep <- suppressMessages(suppressWarnings(
    dv_prepare(df, spec, taxonomy = "columns", verbose = FALSE)))
  out <- tempfile(fileext = ".html")
  on.exit(unlink(out), add = TRUE)
  expect_warning(
    dv_build_html(prep, output = out, strata = character(0), bands = "count",
                  self_contained = FALSE),
    "1 record\\(s\\) have no predator")
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # "A-b" and "A b" both reduce to "A_b"; the index keeps the two tabs apart
  for (id in c("view_p1_A_b", "view_p2_A_b")) {
    expect_match(html, sprintf("id=\"%s\"", id), fixed = TRUE)
    expect_match(html, sprintf("showTab(&#39;%s&#39;)", id), fixed = TRUE)
  }
})

test_that("a '|' inside a taxon label does not break node ids", {
  df <- data.frame(phylum = c("A|B", "A|B", "C"), class = c("x", "y", "x"))
  tree <- dv_build_tree(df, c("phylum", "class"))
  expect_equal(nrow(tree), 5L)
  expect_true("A|B" %in% tree$label)                 # label unchanged
  expect_equal(lengths(strsplit(tree$id, "|", fixed = TRUE)),
               ifelse(tree$rank == "Phylum", 1L, 2L))
  # every parent is a node id
  par <- tree$parent[tree$parent != ""]
  expect_true(all(par %in% tree$id))
  expect_equal(sum(tree$value_occ[tree$parent == tree$id[tree$label == "A|B"]]), 2)
  cols <- dv_palette_tree(tree, base_rank = 1L)
  expect_equal(names(cols), tree$id)
  expect_equal(unname(cols[tree$label == "x" & tree$parent != "C"]) == "#BDBDBD", FALSE)
})

test_that("dv_palette_tree() does not depend on the row order of the tree", {
  tree <- dv_tree(example_prep())
  set.seed(8317)
  shuffled <- tree[sample(nrow(tree)), ]
  expect_equal(dv_palette_tree(shuffled)[tree$id], dv_palette_tree(tree))
})

# --- WoRMS cache --------------------------------------------------------------

no_keys <- data.frame(prey_id = integer(0), prey_name = character(0))
cache_path <- function(dir) file.path(dir, "worms_lineage.rds")
run_worms <- function(keys, dir, ...) suppressMessages(
  dv_taxonomy_worms(keys, cache_dir = dir, verbose = FALSE, ...))

test_that("an unreadable cache file is ignored with a warning and rebuilt", {
  skip_if_not_installed("worrms")
  skip_if_not_installed("withr")
  local_mocked_bindings(
    wm_record = function(id, ...) data.frame(
      AphiaID = id, scientificname = "Gadus morhua", status = "accepted",
      valid_AphiaID = id, valid_name = "Gadus morhua"),
    wm_classification = function(id, ...) data.frame(
      rank = c("Kingdom", "Phylum"), scientificname = c("Animalia", "Chordata")),
    .package = "worrms"
  )
  dir <- withr::local_tempdir()
  writeLines("this is not an rds file", cache_path(dir))
  keys <- data.frame(prey_id = 126436L, prey_name = "Gadus morhua")
  expect_warning(out <- run_worms(keys, dir), "could not be read")
  expect_equal(out$phylum, "Chordata")
  cache <- readRDS(cache_path(dir))
  expect_true(all(c("rec:126436", "id:126436") %in% names(cache)))
  expect_false(file.exists(paste0(cache_path(dir), ".tmp")))
})

test_that("expired and undated cache entries are removed from the file", {
  skip_if_not_installed("worrms")
  skip_if_not_installed("withr")
  dir <- withr::local_tempdir()
  now <- Sys.time()
  saveRDS(list(old     = list(v = 1, t = now - 200 * 86400),
               fresh   = list(v = 2, t = now - 10 * 86400),
               undated = c(kingdom = NA_character_)),
          cache_path(dir))
  run_worms(no_keys, dir, cache_max_age = 180)
  expect_equal(names(readRDS(cache_path(dir))), "fresh")
  # Inf trusts every dated entry
  saveRDS(list(old = list(v = 1, t = now - 2000 * 86400)), cache_path(dir))
  run_worms(no_keys, dir, cache_max_age = Inf)
  expect_equal(names(readRDS(cache_path(dir))), "old")
})

test_that("the cache file is not rewritten when nothing changed", {
  skip_if_not_installed("worrms")
  skip_if_not_installed("withr")
  dir <- withr::local_tempdir()
  saveRDS(list(fresh = list(v = 2, t = Sys.time())), cache_path(dir))
  old_time <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  Sys.setFileTime(cache_path(dir), old_time)
  run_worms(no_keys, dir)
  expect_equal(as.numeric(file.mtime(cache_path(dir))), as.numeric(old_time))
})

test_that("dv_cache_clear() deletes the cache and an emptied cache folder only", {
  dir <- file.path(tempfile("dv_cache_"), "cache")
  dir.create(dir, recursive = TRUE)
  on.exit(unlink(dirname(dir), recursive = TRUE), add = TRUE)
  saveRDS(list(), cache_path(dir))
  expect_true(dv_cache_clear(dir))
  expect_false(dir.exists(dir))
  expect_false(dv_cache_clear(dir))                  # nothing left to delete

  dir.create(dir)
  saveRDS(list(), cache_path(dir))
  writeLines("keep me", file.path(dir, "other.txt"))
  expect_true(dv_cache_clear(dir))
  expect_true(file.exists(file.path(dir, "other.txt")))   # other files untouched
})
