# Offline GBIF: .dv_gbif_get() is replaced by a lookup in canned answers that
# copy the shape of the GBIF v1 API (species/{key} and species/match).

gbif_answers <- list(
  "species/2222204" = list(key = 2222204L, nubKey = 2222204L,
    datasetKey = "d7dddbf4-2cf0-4f39-9b2a-bb099caae36c",
    canonicalName = "Crangon vulgaris", rank = "SPECIES", acceptedKey = 2222188L,
    kingdom = "Animalia", phylum = "Arthropoda", class = "Malacostraca",
    order = "Decapoda", family = "Crangonidae", genus = "Crangon",
    species = "Crangon crangon"),
  "species/8084280" = list(key = 8084280L, nubKey = 8084280L,
    datasetKey = "d7dddbf4-2cf0-4f39-9b2a-bb099caae36c",
    canonicalName = "Gadus morhua", rank = "SPECIES",
    kingdom = "Animalia", phylum = "Chordata", order = "Gadiformes",
    family = "Gadidae", genus = "Gadus", species = "Gadus morhua"),
  "name=Gadus%20morua" = list(usageKey = 8084280L, canonicalName = "Gadus morhua",
    rank = "SPECIES", status = "ACCEPTED", confidence = 96L, matchType = "FUZZY",
    kingdom = "Animalia", phylum = "Chordata", order = "Gadiformes",
    family = "Gadidae", genus = "Gadus", species = "Gadus morhua"),
  "name=Gadus%20morhua" = list(usageKey = 8084280L, canonicalName = "Gadus morhua",
    rank = "SPECIES", status = "ACCEPTED", confidence = 99L, matchType = "EXACT",
    kingdom = "Animalia", phylum = "Chordata", order = "Gadiformes",
    family = "Gadidae", genus = "Gadus", species = "Gadus morhua"),
  "name=Crangon%20vulgaris" = list(usageKey = 2222204L, acceptedUsageKey = 2222188L,
    canonicalName = "Crangon vulgaris", rank = "SPECIES", status = "SYNONYM",
    confidence = 98L, matchType = "EXACT", kingdom = "Animalia",
    phylum = "Arthropoda", class = "Malacostraca", order = "Decapoda",
    family = "Crangonidae", genus = "Crangon", species = "Crangon crangon"),
  "name=Pandalus%20xenus" = list(usageKey = 2222352L, canonicalName = "Pandalus",
    rank = "GENUS", status = "ACCEPTED", confidence = 80L, matchType = "HIGHERRANK",
    kingdom = "Animalia", phylum = "Arthropoda", class = "Malacostraca",
    order = "Decapoda", family = "Pandalidae", genus = "Pandalus"),
  "name=Zzzz%20qqq" = list(confidence = 100L, matchType = "NONE"),
  "name=Isopoda" = list(usageKey = 54L, canonicalName = "Arthropoda", rank = "PHYLUM",
    status = "ACCEPTED", confidence = 92L, matchType = "HIGHERRANK",
    kingdom = "Animalia", phylum = "Arthropoda",
    alternatives = list(
      list(usageKey = 643L, canonicalName = "Isopoda", rank = "ORDER",
           status = "ACCEPTED", matchType = "EXACT", confidence = 92L,
           kingdom = "Animalia", phylum = "Arthropoda", class = "Malacostraca",
           order = "Isopoda"),
      list(usageKey = 3253116L, canonicalName = "Isopoda", rank = "GENUS",
           status = "SYNONYM", matchType = "EXACT", confidence = 92L,
           kingdom = "Animalia", phylum = "Arthropoda", class = "Arachnida"))),
  "name=Polychaeta" = list(usageKey = 1L, canonicalName = "Animalia", rank = "KINGDOM",
    status = "ACCEPTED", confidence = 92L, matchType = "HIGHERRANK",
    kingdom = "Animalia",
    alternatives = list(
      list(usageKey = 256L, canonicalName = "Polychaeta", rank = "CLASS",
           status = "ACCEPTED", matchType = "EXACT", kingdom = "Animalia",
           phylum = "Annelida", class = "Polychaeta"),
      list(usageKey = 1464857L, canonicalName = "Polychaeta", rank = "GENUS",
           status = "ACCEPTED", matchType = "EXACT", kingdom = "Animalia",
           phylum = "Arthropoda", class = "Insecta", genus = "Polychaeta"))),
  "name=Twin" = list(confidence = 100L, matchType = "NONE",
                     note = "Multiple equal matches for Twin")
)

local_gbif <- function(answers = gbif_answers, fail = character(0),
                       calls = NULL, .env = parent.frame()) {
  testthat::local_mocked_bindings(
    .dv_gbif_get = function(u) {
      if (!is.null(calls)) calls$n <- calls$n + 1L
      key <- sub("^.*/v1/", "", u)
      key <- sub("^species/match\\?", "", key)
      key <- sub("&.*$", "", key)
      if (key %in% fail) stop("cannot open URL: HTTP status was '503 Service Unavailable'")
      a <- answers[[key]]
      if (is.null(a)) stop("cannot open URL: HTTP status was '404 Not Found'")
      a
    },
    .dv_sleep = function(seconds) invisible(NULL),
    .package = "DietView", .env = .env)
}

test_that("GBIF resolves keys, synonyms, exact, fuzzy, higher-rank and no match", {
  local_gbif()
  keys <- data.frame(
    prey_id   = c(NA, NA, NA, NA, 2222204, 99999999, NA),
    prey_name = c("Gadus morua", "Crangon vulgaris", "Pandalus xenus", "Zzzz qqq",
                  "Crangon vulgaris", "Gadus morhua", NA),
    stringsAsFactors = FALSE)
  out <- dv_taxonomy_gbif(keys, cache_dir = NULL, verbose = FALSE)
  expect_equal(out$match_type, c("fuzzy", "exact", "higherrank", "unresolved",
                                 "id_synonym", "id_fallback_name", "unresolved"))
  expect_equal(out$gbif_key, c(8084280L, 2222188L, 2222352L, NA, 2222188L, 8084280L, NA))
  # synonyms get the accepted classification and name
  expect_equal(out$species[c(2, 5)], c("Crangon crangon", "Crangon crangon"))
  expect_equal(out$matched_name[2], "Crangon crangon")
  expect_equal(out$name_check[5], "agrees")
  # a higher-rank match stops at that rank
  expect_equal(out$genus[3], "Pandalus")
  expect_true(is.na(out$species[3]))
  expect_true(out$low_confidence[3])
  # no class in the GBIF Backbone for gadids
  expect_true(is.na(out$class[1]))
  expect_true(all(is.na(unlist(out[4, c("kingdom", "species")]))))
})

test_that("strict matching turns fuzzy hits into unresolved", {
  local_gbif()
  out <- dv_taxonomy_gbif(data.frame(prey_name = "Gadus morua"), cache_dir = NULL,
                          fuzzy = FALSE, verbose = FALSE)
  expect_equal(out$match_type, "unresolved")
})

test_that("GBIF homonyms are flagged and failures are reported, not cached", {
  local_gbif(fail = "name=Gadus%20morhua")
  dir <- withr::local_tempdir()
  expect_warning(
    out <- dv_taxonomy_gbif(data.frame(prey_name = c("Twin", "Gadus morhua")),
                            cache_dir = dir, verbose = FALSE),
    "could not be looked up in GBIF")
  expect_true(out$homonym[1])
  expect_equal(out$match_type, c("unresolved", "unresolved"))
  expect_false(out$lineage_ok[2])
  cache <- readRDS(file.path(dir, "gbif_lineage.rds"))
  expect_false(any(grepl("gadus morhua", names(cache))))
})

test_that("successful GBIF lookups are served from the cache", {
  calls <- new.env(); calls$n <- 0L
  local_gbif(calls = calls)
  dir <- withr::local_tempdir()
  k <- data.frame(prey_name = c("Gadus morhua", "Crangon vulgaris"))
  a <- dv_taxonomy_gbif(k, cache_dir = dir, verbose = FALSE)
  n1 <- calls$n
  b <- dv_taxonomy_gbif(k, cache_dir = dir, verbose = FALSE)
  expect_equal(calls$n, n1)
  expect_equal(a$species, b$species)
  expect_true(dv_cache_clear(dir, source = "gbif"))
  expect_false(dir.exists(dir))
})

test_that("dv_prepare(taxonomy = 'gbif') builds the log, the report and gap labels", {
  local_gbif()
  d <- data.frame(pred = "cod", st = c("s1", "s1", "s2", "s3"),
                  prey = c("Gadus morhua", "Crangon vulgaris", "Pandalus xenus", "Zzzz qqq"),
                  w = c(10, 2, 1, 0.5), stringsAsFactors = FALSE)
  spec <- dv_spec(predator = "pred", stomach = "st", prey_name = "prey", weight = "w")
  prep <- dv_prepare(d, spec, taxonomy = "gbif", cache_dir = NULL, verbose = FALSE)
  expect_equal(prep$taxonomy_source, "gbif")
  expect_equal(attr(prep$taxonomy_log, "source"), "GBIF Backbone")
  expect_true(all(c("gbif_key", "confidence", "low_confidence") %in% names(prep$taxonomy_log)))
  expect_false("aphia_used" %in% names(prep$taxonomy_log))
  # the class gap of gadids is labelled, not left unidentified
  expect_equal(prep$data$class[1], "Chordata (no class)")
  rev <- dv_taxonomy_report(prep)
  expect_setequal(rev$prey_name, c("Pandalus xenus", "Zzzz qqq"))
  tree <- dv_tree(prep)
  expect_equal(sum(tree$pct_occ[tree$rank == "Species"]), 100)
  expect_match(paste(unclass(dv_script(prep)), collapse = "\n"), "GBIF Backbone")
})

test_that("one exact accepted alternative is taken; several are a homonym", {
  local_gbif()
  out <- dv_taxonomy_gbif(data.frame(prey_name = c("Isopoda", "Polychaeta")),
                          cache_dir = NULL, verbose = FALSE)
  expect_equal(out$match_type, c("exact", "unresolved"))
  expect_equal(out$order[1], "Isopoda")
  expect_equal(out$class[1], "Malacostraca")
  expect_false(out$homonym[1])
  expect_true(out$homonym[2])
  expect_equal(out$n_candidates, c(2L, 2L))
  expect_true(is.na(out$kingdom[2]))        # a kingdom alone is no match
})
