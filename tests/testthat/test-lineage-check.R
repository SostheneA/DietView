test_that("dv_lineage_check flags spelling variants and misplaced labels", {
  lin <- data.frame(
    key     = 1:5,
    kingdom = "Animalia",
    phylum  = c("Chordata", "Chordata", "Chordata", "Annelida", "Arthropoda"),
    class   = c("Teleostei", "Teleostei", "Teleostei", "Polychaeta", "Polychaeta"),
    order   = c("Gadiformes", "Gadiformes", "Gadiformes", NA, NA),
    family  = c("Gadidae", "Gadidae", "Gadidae", NA, NA),
    genus   = c("Trisopterus", "Trisopterus", "Gadus", NA, NA),
    species = c("Trisopterus esmarkii", "Trisopterus esmarki", "Merlangius merlangus",
                NA, NA))
  chk <- dv_lineage_check(lin)
  expect_true(any(chk$check == "near_duplicate" & chk$rank == "species"))
  expect_true(any(chk$check == "multi_parent" & chk$label == "Polychaeta"))
  expect_true(any(chk$check == "genus_mismatch" & chk$label == "Merlangius merlangus"))
  # short labels two edits apart (Porifera / Rotifera style) are not flagged
  short <- data.frame(kingdom = "Animalia", phylum = c("Porifera", "Rotifera"),
                      class = NA, order = NA, family = NA, genus = NA, species = NA)
  expect_equal(nrow(dv_lineage_check(short)), 0L)
})

test_that("dv_lineage_check counts records on a prep and finds the ICES variants", {
  chk <- dv_lineage_check(ices_lineage)
  nd <- chk[chk$check == "near_duplicate", ]
  expect_true(any(nd$label == "Trisopterus esmarki" | nd$variant == "Trisopterus esmarki"))
  expect_true(all(is.na(chk$n_records)))
  # unidentified material has no prey key; dv_validate() warns about it
  prep <- suppressWarnings(
    dv_prepare(ices_diet[ices_diet$predator_common == "Whiting", ],
               dv_spec(predator = "predator_common", stomach = "stomach_id",
                       prey_id = "prey_aphia_id"),
               taxonomy = "table", lineage = ices_lineage, verbose = FALSE))
  chk_p <- dv_lineage_check(prep)
  expect_true(all(chk_p$n_records >= 0))
  expect_named(chk_p, c("check", "rank", "parent", "label", "variant",
                        "distance", "n_records"))
})
