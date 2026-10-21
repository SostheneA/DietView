test_that("records without an AphiaID are matched by their own name", {
  skip_if_not_installed("worrms")
  cls <- function(ranks, names) data.frame(rank = ranks, scientificname = names)
  local_mocked_bindings(
    wm_record = function(id, ...) data.frame(AphiaID = id, scientificname = "Pandalus borealis",
                  status = "accepted", valid_AphiaID = id, valid_name = "Pandalus borealis"),
    wm_classification = function(id, ...) {
      if (id == 107649) cls(c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species"),
                            c("Animalia", "Arthropoda", "Malacostraca", "Decapoda",
                              "Pandalidae", "Pandalus", "Pandalus borealis"))
      else cls(c("Kingdom", "Phylum", "Class", "Order", "Family"),
               c("Animalia", "Arthropoda", "Malacostraca", "Decapoda", "Crangonidae"))
    },
    wm_records_names = function(name, ...) {
      if (identical(name, "Crangonidae"))   # 999001 is a fake ID for the mock
        list(data.frame(AphiaID = 999001L, scientificname = "Crangonidae", status = "accepted",
                        valid_AphiaID = 999001L, valid_name = "Crangonidae"))
      else stop("no match")
    },
    wm_records_taxamatch = function(name, ...) stop("no match"),
    .package = "worrms"
  )
  dat <- data.frame(pred = "cod", stom = c("s1", "s1", "s2", "s3"),
                    aphia = c(107649, NA, NA, NA),
                    name  = c("Pandalus borealis", "Crangonidae", "unidentified material", "Crangonidae"))
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_id = "aphia", prey_name = "name")
  prep <- suppressMessages(suppressWarnings(
    dv_prepare(dat, spec, taxonomy = "worms", cache_dir = NULL, verbose = FALSE)))
  expect_equal(prep$data$family, c("Pandalidae", "Crangonidae", NA, "Crangonidae"))
  expect_true(all(is.na(unlist(prep$data[3, prep$ranks]))))
  expect_equal(sum(prep$taxonomy_log$n_records), 4)   # every record counted once in the log
})

test_that("a failed classification is flagged and not cached", {
  skip_if_not_installed("worrms")
  calls <- 0L
  local_mocked_bindings(
    wm_record = function(id, ...) data.frame(AphiaID = id, scientificname = "Pandalus borealis",
                  status = "accepted", valid_AphiaID = id, valid_name = "Pandalus borealis"),
    wm_classification = function(id, ...) { calls <<- calls + 1L; stop("timeout") },
    wm_records_names = function(name, ...) stop("no match"),
    wm_records_taxamatch = function(name, ...) stop("no match"),
    .package = "worrms"
  )
  dir <- withr::local_tempdir()
  dat  <- data.frame(pred = "cod", stom = "s1", aphia = 107649, name = "Pandalus borealis")
  spec <- dv_spec(predator = "pred", stomach = "stom", prey_id = "aphia", prey_name = "name")
  run  <- function() suppressMessages(dv_prepare(dat, spec, taxonomy = "worms",
                                                 cache_dir = dir, verbose = FALSE))
  expect_warning(p1 <- run(), "no classification")
  expect_false(p1$taxonomy_log$lineage_ok)
  expect_warning(run(), "no classification")
  expect_equal(calls, 2L)                              # second run asked WoRMS again
})
