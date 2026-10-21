# The bundled ICES datasets: structure, keys, units, and the standard set-up
# used in the examples and vignettes.

ices_standard_data <- function() {
  phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id,
                                      ices_lineage$prey_aphia_id)]
  ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
}
ices_standard_spec <- function() dv_spec(
  predator       = "predator_common",
  predator_latin = "predator_latin",
  stomach        = "stomach_id",
  prey_id        = "prey_aphia_id",
  prey_name      = "prey_name",
  weight         = "prey_weight_g",
  count          = "prey_count",
  digestion      = "digestion_label",
  covariates     = c("region", "year", "quarter")
)
ices_standard_prep <- function(dat = ices_standard_data()) {
  dv_prepare(dat, ices_standard_spec(), taxonomy = "table",
             lineage = ices_lineage, verbose = FALSE)
}

test_that("the ICES datasets have the documented dimensions", {
  expect_s3_class(ices_diet, "data.frame")
  expect_equal(dim(ices_diet), c(9639L, 28L))
  expect_equal(length(unique(ices_diet$stomach_id)), 4231L)
  expect_equal(length(unique(ices_diet$predator_common)), 22L)
  expect_equal(nrow(ices_stomachs), 8886L)
  expect_equal(sum(ices_stomachs$stomach_empty == 1, na.rm = TRUE), 1197L)
  expect_false(anyDuplicated(ices_stomachs$stomach_id) > 0)
  expect_true(all(ices_diet$stomach_id %in% ices_stomachs$stomach_id))
  expect_false(anyDuplicated(ices_lineage$prey_aphia_id) > 0)
  expect_true(all(c("prey_aphia_id", "kingdom", "phylum", "class", "order",
                    "family", "genus", "species") %in% names(ices_lineage)))
})

test_that("every prey AphiaID of ices_diet is in ices_lineage", {
  ids <- unique(ices_diet$prey_aphia_id[!is.na(ices_diet$prey_aphia_id)])
  expect_true(all(ids %in% ices_lineage$prey_aphia_id))
})

test_that("item_type takes the three documented values", {
  expect_setequal(unique(ices_diet$item_type),
                  c("prey", "unidentified", "non_food"))
  expect_false(anyNA(ices_diet$item_type))
  expect_equal(sum(ices_diet$item_type == "non_food"), 67L)
  # unidentified material and non-food items have no AphiaID
  expect_true(all(is.na(ices_diet$prey_aphia_id[ices_diet$item_type != "prey"])))
})

test_that("units are sane after the corrections", {
  expect_true(all(ices_diet$length_cm <= 150, na.rm = TRUE))
  expect_true(all(ices_stomachs$length_cm <= 150, na.rm = TRUE))
  expect_true(all(ices_diet$prey_weight_g >= 0, na.rm = TRUE))
  # Fulton's condition factor K = 100 W / L^3 (g, cm) of Atlantic cod
  cod <- ices_stomachs[ices_stomachs$predator_common == "Atlantic cod" &
                         !is.na(ices_stomachs$weight_g) &
                         !is.na(ices_stomachs$length_cm), ]
  expect_gt(nrow(cod), 100)
  k <- 100 * cod$weight_g / cod$length_cm^3
  expect_gt(mean(k > 0.4 & k < 2), 0.95)
})

test_that("the standard set-up prepares 22 predators and closed trees", {
  prep <- ices_standard_prep()
  expect_s3_class(prep, "dietview_prep")
  expect_equal(length(unique(prep$data$predator_common)), 22L)
  expect_false(any(prep$data$item_type == "non_food"))
  expect_false(any(prep$data$phylum %in% "Nematoda"))

  tree <- dv_tree(prep)
  pct <- tapply(tree$pct_occ, tree$rank, sum)
  expect_true(all(abs(pct - 100) < 1e-6))
  w <- tapply(tree$pct_w, tree$rank, sum)
  expect_true(all(abs(w - 100) < 1e-6))
  expect_true(all(tapply(tree$value_occ, tree$rank, sum) == nrow(prep$data)))
})

test_that("dv_fo_table runs on the ICES data", {
  dat <- ices_standard_data()
  prep <- ices_standard_prep(dat[dat$predator_common == "Atlantic cod", ])
  fo <- dv_fo_table(prep, rank = "class")
  expect_s3_class(fo, "data.frame")
  expect_gt(nrow(fo), 1)
  expect_true(all(fo$pct_fo >= 0 & fo$pct_fo <= 100))
  expect_equal(unique(fo$n_total), length(unique(prep$data$stomach_id)))
  expect_true("Malacostraca" %in% fo$taxon)
})
