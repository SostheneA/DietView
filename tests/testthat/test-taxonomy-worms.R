test_that("records without an AphiaID are matched by their own name", {
  skip_if_not_installed("worrms")
  cls <- function(ranks, names) data.frame(rank = ranks, scientificname = names)
  local_worms(
    record = function(id, ...) data.frame(AphiaID = id, scientificname = "Pandalus borealis",
                  status = "accepted", valid_AphiaID = id, valid_name = "Pandalus borealis"),
    classification = function(id, ...) {
      if (id == 107649) cls(c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species"),
                            c("Animalia", "Arthropoda", "Malacostraca", "Decapoda",
                              "Pandalidae", "Pandalus", "Pandalus borealis"))
      else cls(c("Kingdom", "Phylum", "Class", "Order", "Family"),
               c("Animalia", "Arthropoda", "Malacostraca", "Decapoda", "Crangonidae"))
    },
    names = function(name, ...) {
      if (identical(name, "Crangonidae"))   # 999001 is a fake ID for the mock
        list(data.frame(AphiaID = 999001L, scientificname = "Crangonidae", status = "accepted",
                        valid_AphiaID = 999001L, valid_name = "Crangonidae"))
      else stop("(204) No Content")
    },
    taxamatch = function(name, ...) stop("(204) No Content")
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
  local_worms(
    record = function(id, ...) data.frame(AphiaID = id, scientificname = "Pandalus borealis",
                  status = "accepted", valid_AphiaID = id, valid_name = "Pandalus borealis"),
    classification = function(id, ...) { calls <<- calls + 1L; stop("timeout") },
    names = function(name, ...) stop("(204) No Content"),
    taxamatch = function(name, ...) stop("(204) No Content")
  )
  skip_if_not_installed("withr")
  withr::local_options(DietView.worms_retries = 0L)   # one request per run
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

# --- batching, retries, "no match" detection, fallback to the name -----------

fake_record <- function(id, ...) data.frame(
  AphiaID = id, scientificname = paste("Taxon", id), status = "accepted",
  valid_AphiaID = id, valid_name = paste("Taxon", id))
fake_class <- function(id, ...) data.frame(
  rank = c("Kingdom", "Phylum", "Species"),
  scientificname = c("Animalia", "Chordata", paste("Taxon", id)))

test_that("records, classifications and names are requested in chunks", {
  skip_if_not_installed("worrms")
  n_rec <- 0L; n_cls <- 0L; n_nm <- 0L
  local_worms(record = fake_record, classification = fake_class,
              names = function(name, ...) stop("(204) No Content"),
              taxamatch = function(name, ...) stop("(204) No Content"))
  # count the vectorised calls on top of the per-item fakes
  rec_v <- worms_vectorised(record = fake_record)$wm_record
  cls_v <- worms_vectorised(classification = fake_class)$wm_classification_
  nm_v  <- worms_vectorised(names = function(name, ...) stop("(204) No Content"))$wm_records_names
  local_mocked_bindings(
    wm_record = function(id, ...) { n_rec <<- n_rec + 1L; rec_v(id) },
    wm_classification_ = function(id = NULL, ...) { n_cls <<- n_cls + 1L; cls_v(id = id) },
    wm_records_names = function(name, ...) { n_nm <<- n_nm + 1L; nm_v(name, ...) },
    .package = "worrms")
  keys <- data.frame(prey_id = c(seq(1000L, 1119L), rep(NA, 60)),
                     prey_name = c(rep(NA, 120), paste("name", 1:60)))
  out <- dv_taxonomy_worms(keys, cache_dir = NULL, fuzzy = FALSE, verbose = FALSE)
  expect_equal(c(n_rec, n_cls, n_nm), c(3L, 3L, 2L))    # 50 + 50 + 20; 50 + 10
  expect_equal(out$species[1:3], paste("Taxon", 1000:1002))
  expect_true(all(out$match_type[1:120] == "id"))
  expect_true(all(out$match_type[121:180] == "unresolved"))
})

test_that("a failed request is retried with backoff, then flagged", {
  skip_if_not_installed("worrms")
  skip_if_not_installed("withr")
  attempts <- 0L; sleeps <- numeric(0)
  local_worms(record = fake_record, classification = fake_class)
  cls_v <- worms_vectorised(classification = fake_class)$wm_classification_
  local_mocked_bindings(
    wm_classification_ = function(id = NULL, ...) {
      attempts <<- attempts + 1L
      if (attempts <= 2L) stop("Timeout was reached")
      cls_v(id = id)
    }, .package = "worrms")
  local_mocked_bindings(.dv_sleep = function(seconds) sleeps <<- c(sleeps, seconds))
  keys <- data.frame(prey_id = 126436L, prey_name = "Gadus morhua")
  out <- dv_taxonomy_worms(keys, cache_dir = NULL, verbose = FALSE)
  expect_equal(attempts, 3L)
  expect_equal(sleeps, c(1, 2))
  expect_true(out$lineage_ok)

  # the number of retries is an option; a request that keeps failing is flagged
  attempts <- 0L; sleeps <- numeric(0)
  local_mocked_bindings(wm_classification_ = function(id = NULL, ...) {
    attempts <<- attempts + 1L; stop("Timeout was reached") }, .package = "worrms")
  withr::local_options(DietView.worms_retries = 1L)
  expect_warning(out <- dv_taxonomy_worms(keys, cache_dir = NULL, verbose = FALSE),
                 "no classification")
  expect_equal(attempts, 2L)
  expect_equal(sleeps, 1)
  expect_false(out$lineage_ok)
})

test_that("a no-match answer is final and not retried", {
  skip_if_not_installed("worrms")
  calls <- 0L
  local_worms(record = fake_record,
              classification = function(id, ...) {
                calls <<- calls + 1L
                if (id == 2L) stop("(204) No Content") else fake_class(id)
              })
  keys <- data.frame(prey_id = c(1L, 2L), prey_name = NA)
  out <- suppressWarnings(dv_taxonomy_worms(keys, cache_dir = NULL, verbose = FALSE))
  expect_equal(calls, 2L)                     # one try each, no retry for ID 2
  expect_equal(out$lineage_ok, c(TRUE, FALSE))
})

test_that("no match is read from the HTTP status when the condition has one", {
  nm <- DietView:::.dv_is_no_match
  # structured status: wins over the message
  e204 <- structure(class = c("http_error", "error", "condition"),
                    list(message = "request failed", call = NULL, status_code = 204L))
  e500 <- structure(class = c("http_error", "error", "condition"),
                    list(message = "(204) mentioned but status is 500", call = NULL,
                         status_code = 500L))
  e_resp <- structure(class = c("error", "condition"),
                      list(message = "x", call = NULL, response = list(status_code = 204)))
  e_cls <- structure(class = c("http_204", "error", "condition"),
                     list(message = "No luck", call = NULL))
  expect_true(nm(e204)); expect_false(nm(e500)); expect_true(nm(e_resp)); expect_true(nm(e_cls))
  # message fallback (what worrms 0.4 raises)
  expect_true(nm(simpleError("(204) No Content - AphiaRecordsByNames")))
  expect_false(nm(simpleError("Timeout was reached: port 2043")))
  expect_true(nm(simpleWarning("(204) No Content - 126436")))
})

test_that("an AphiaID unknown to WoRMS falls back to the prey name", {
  skip_if_not_installed("worrms")
  local_worms(
    record = function(id, ...) if (id == 999L) stop("(204) No Content") else fake_record(id),
    classification = function(id, ...) if (id == 999L) stop("(204) No Content") else fake_class(id),
    names = function(name, ...) {
      if (name == "Gadus morhua") data.frame(AphiaID = 126436L, scientificname = "Gadus morhua",
                                             status = "accepted", valid_AphiaID = 126436L,
                                             valid_name = "Gadus morhua")
      else stop("(204) No Content")
    },
    taxamatch = function(name, ...) stop("(204) No Content"))
  keys <- data.frame(prey_id = c(999L, 999L, 5L), prey_name = c("Gadus morhua", "Nothing", NA))
  keys <- keys[c(1, 3), ]                                   # one key per prey
  out <- dv_taxonomy_worms(keys, cache_dir = NULL, verbose = FALSE)
  expect_equal(out$match_type, c("id_fallback_name", "id"))
  expect_equal(out$aphia_used, c(126436L, 5L))
  expect_equal(out$species[1], "Taxon 126436")
  expect_true(out$lineage_ok[1])
  expect_equal(nrow(DietView:::.dv_review_rows(out)), 1L)
  expect_true("id_fallback_name" %in% DietView:::.DV_MATCH_TYPES)
  # without a usable name the AphiaID stays unchecked and unresolved
  out2 <- suppressWarnings(dv_taxonomy_worms(data.frame(prey_id = 999L, prey_name = "Nothing"),
                                             cache_dir = NULL, verbose = FALSE))
  expect_equal(out2$match_type, "unresolved")
})
