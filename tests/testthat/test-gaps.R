# Lineage gaps: a rank WoRMS does not define for a group, above an identified
# rank, is labelled "<ancestor> (no <rank>)" instead of sitting under "NA".

ices_gap_preps <- function() {
  phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
  dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
  spec <- dv_spec(predator = "predator_common", predator_latin = "predator_latin",
                  stomach = "stomach_id", prey_id = "prey_aphia_id",
                  prey_name = "prey_name", weight = "prey_weight_g",
                  count = "prey_count", digestion = "digestion_label",
                  covariates = c("region", "year", "quarter"))
  list(
    label = dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE),
    keep  = dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE, gaps = "keep"))
}
P <- ices_gap_preps()

test_that("no identified node sits under an NA parent", {
  tree <- dv_tree(P$label)
  under_na <- tree$label != "NA" & grepl("(^|\\|)NA(\\||$)", tree$parent)
  expect_false(any(under_na))
  # the old behaviour did have such nodes
  tk <- dv_tree(P$keep)
  expect_true(any(tk$label != "NA" & grepl("(^|\\|)NA(\\||$)", tk$parent)))
})

test_that("Polychaeta (no order) holds the polychaete families without an order", {
  tree <- dv_tree(P$label)
  node <- tree[tree$label == "Polychaeta (no order)", ]
  expect_equal(nrow(node), 1L)
  expect_equal(node$rank, "Order")
  d <- P$keep$data
  n_expected <- sum(d$class %in% "Polychaeta" & is.na(d$order) & !is.na(d$family))
  expect_gt(n_expected, 0)
  expect_equal(node$value_occ, n_expected)
  gaps <- attr(P$label, "lineage_gaps")
  expect_equal(names(gaps), P$label$ranks)
  expect_equal(unname(gaps["order"]),
               sum(.dv_is_gap(P$label$data$order)))
})

test_that("every rank still sums to 100", {
  tree <- dv_tree(P$label)
  expect_true(all(abs(tapply(tree$pct_occ, tree$rank, sum) - 100) < 1e-8))
  expect_true(all(abs(tapply(tree$pct_w, tree$rank, sum) - 100) < 1e-8))
})

test_that("gaps = 'keep' reproduces the tree without gap labels", {
  expect_false(any(vapply(P$keep$ranks, function(r) any(.dv_is_gap(P$keep$data[[r]])),
                          logical(1))))
  expect_equal(sum(attr(P$keep, "lineage_gaps")), 0L)
  # trailing NAs are untouched: same NA pattern below the deepest identified rank
  for (r in P$label$ranks) {
    filled <- .dv_is_gap(P$label$data[[r]])
    expect_identical(P$label$data[[r]][!filled], P$keep$data[[r]][!filled])
    expect_true(all(is.na(P$keep$data[[r]][filled])))
  }
})

test_that("threshold aggregation gives the same categories either way", {
  for (sc in c("pooled", "per_predator")) {
    a <- dv_aggregate_threshold(P$label, threshold = 10, scope = sc)
    b <- dv_aggregate_threshold(P$keep,  threshold = 10, scope = sc)
    expect_identical(a$data$prey_category, b$data$prey_category)
    expect_identical(a$data$prey_rank, b$data$prey_rank)
    expect_false(any(.dv_is_gap(a$data$prey_category)))
  }
})

test_that("gap nodes are light gray in both palettes, NA stays white", {
  tree <- dv_tree(P$label)
  cols <- dv_palette_tree(tree)
  gap <- .dv_is_gap(tree$label)
  expect_true(all(cols[tree$id[gap]] == .DV_GAP_COLOR))
  expect_true(all(cols[tree$id[tree$label == "NA"]] == "#FFFFFF"))
  # descendants of a gap keep the tint of their base-rank ancestor (not gray)
  kids <- tree$id[tree$parent %in% tree$id[tree$label == "Polychaeta (no order)"]]
  expect_true(all(!cols[kids] %in% c(.DV_GAP_COLOR, "#BDBDBD", "#FFFFFF")))
  pal <- dv_palette(tree$label)
  expect_true(all(pal[tree$label[gap]] == .DV_GAP_COLOR))
  expect_equal(unname(pal["NA"]), "#FFFFFF")
})

test_that("richness and the digestion diagnostic are unchanged", {
  expect_identical(dv_summary(P$label)$n_taxa, dv_summary(P$keep)$n_taxa)
  expect_identical(dv_digestion_diagnostic(P$label), dv_digestion_diagnostic(P$keep))
  expect_identical(.dv_leaf_label(P$label$data, P$label$ranks),
                   .dv_leaf_label(P$keep$data, P$keep$ranks))
})

test_that("gap labels are recognised and not flagged by dv_lineage_check()", {
  expect_true(all(.dv_is_gap(c("Polychaeta (no order)", "(no class)"))))
  expect_false(any(.dv_is_gap(c("Polychaeta", "NA", NA, "Gadus (other)"))))
  expect_equal(.dv_gap_label(c("Polychaeta", NA), "Order"),
               c("Polychaeta (no order)", "(no order)"))
  chk <- dv_lineage_check(P$label)
  expect_false(any(.dv_is_gap(chk$label) | .dv_is_gap(chk$parent)))
  expect_equal(nrow(chk), nrow(dv_lineage_check(P$keep)))
})

test_that("the hover text describes a gap as identified material", {
  tree <- dv_tree(P$label)
  pp <- .dv_sb_prep(tree, "occurrence")
  h <- pp$tree$hovertext[pp$tree$label == "Polychaeta (no order)"]
  expect_match(h, "Polychaeta \u2014 no order in WoRMS (identified material)", fixed = TRUE)
})
