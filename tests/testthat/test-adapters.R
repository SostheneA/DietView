test_that("dv_parse_lineage reads prefixed strings, placeholders and epithets", {
  x <- data.frame(lin = c(
    "k__Animalia; p__Arthropoda; c__Copepoda; o__Calanoida; f__Calanidae; g__Calanus; s__finmarchicus",
    "k__Animalia; p__Chordata; c__Actinopteri; o__; f__; g__; s__",
    "d__Eukaryota;k__Animalia;p__Mollusca;c__uncultured;g__Loligo;s__Loligo sp.",
    "Unassigned", NA), stringsAsFactors = FALSE)
  out <- dv_parse_lineage(x, "lin")
  expect_equal(out$species, c("Calanus finmarchicus", NA, NA, NA, NA))
  expect_equal(out$class, c("Copepoda", "Actinopteri", NA, NA, NA))
  expect_equal(out$genus[3], "Loligo")
  expect_true(is.na(out$order[3]))           # absent field, not shifted
  expect_equal(out$kingdom[3], "Animalia")   # d__ ignored without a domain rank
  expect_equal(out$prey_name, c("Calanus finmarchicus", "Actinopteri", "Loligo", NA, NA))
})

test_that("dv_parse_lineage reads positional strings with NCBI tax IDs", {
  y <- data.frame(lin = c(
    "Eukaryota_2759;Arthropoda_6656;Hexanauplia_72037;Calanoida_6833;Calanidae_6834;Calanus_6836;Calanus_finmarchicus_6837",
    "Animalia;Chordata;Actinopteri;Gadiformes;Gadidae;Gadus;Gadus sp."))
  out <- dv_parse_lineage(y, "lin", ranks = c("domain", "phylum", "class", "order",
                                              "family", "genus", "species"))
  expect_equal(out$domain[1], "Eukaryota")
  expect_equal(out$species, c("Calanus finmarchicus", NA))
  expect_equal(out$prey_name, c("Calanus finmarchicus", "Gadus"))
  expect_error(dv_parse_lineage(y, "nope"), "not in `data`")
})

test_that("dv_from_wide pivots ASV tables, joins metadata and collapses", {
  asv <- data.frame(asv = c("a1", "a2", "a3"), tax = c("t1", "t1", "t2"),
                    S1 = c(120, 30, 0), S2 = c(0, NA, 400), stringsAsFactors = FALSE)
  meta <- data.frame(sample = c("S1", "S2"), predator = "seal", season = c("w", "s"))
  long <- dv_from_wide(asv, id_cols = c("asv", "tax"), meta = meta)
  expect_equal(nrow(long), 3)                       # zeros and NA dropped
  expect_equal(long$reads, c(120, 30, 400))
  expect_equal(long$season, c("w", "w", "s"))
  col <- dv_from_wide(asv, id_cols = c("asv", "tax"), collapse_by = "tax")
  expect_equal(col$reads[col$sample == "S1"], 150)
  expect_false("asv" %in% names(col))
  expect_warning(dv_from_wide(asv, id_cols = c("asv", "tax"), meta = meta[1, ]),
                 "no row in `meta`")
  expect_error(dv_from_wide(asv, id_cols = "asv"), "not counts")
})

test_that("dv_from_wide reads samples in rows", {
  w <- data.frame(sample = c("S1", "S2"), predator = "cod",
                  `Calanus finmarchicus` = c(3, 0), Euphausiacea = c(1, 2),
                  check.names = FALSE)
  long <- dv_from_wide(w, taxa_in = "columns", id_cols = c("sample", "predator"),
                       value_col = "n")
  expect_equal(long$prey_name, c("Calanus finmarchicus", "Euphausiacea", "Euphausiacea"))
  expect_equal(long$n, c(3, 1, 2))
  expect_error(dv_from_wide(w, taxa_in = "columns", id_cols = "predator"),
               "must be one of `id_cols`")
})

test_that("weight_type = 'rra' gives the mean relative read abundance", {
  d <- data.frame(pred = "seal", sample = c("S1", "S2", "S3", "S3"),
                  prey = c("A", "B", "A", "B"), reads = c(150, 400, 10, 30),
                  phylum = c("Chordata", "Arthropoda", "Chordata", "Arthropoda"))
  spec <- dv_spec(predator = "pred", stomach = "sample", prey_name = "prey",
                  weight = "reads", weight_type = "rra", ranks = "phylum")
  prep <- dv_prepare(d, spec, taxonomy = "columns", verbose = FALSE)
  expect_equal(prep$spec$weight, "rra")
  expect_equal(prep$spec$weight_raw, "reads")
  expect_true("reads" %in% names(prep$data))
  tr <- dv_tree(prep)
  expect_equal(attr(tr, "weight_type"), "rra")
  # (0 + 1 + 0.75) / 3 samples
  expect_equal(tr$pct_w[tr$label == "Arthropoda"], 100 * 1.75 / 3)
  hov <- .dv_sb_prep(tr, "weight")$tree$hovertext
  expect_match(hov[1], "Mean RRA at this rank")
  # pooled reads instead: 430 / 590
  spec2 <- dv_spec(predator = "pred", stomach = "sample", prey_name = "prey",
                   weight = "reads", weight_type = "reads", ranks = "phylum")
  tr2 <- dv_tree(dv_prepare(d, spec2, taxonomy = "columns", verbose = FALSE))
  expect_equal(tr2$pct_w[tr2$label == "Arthropoda"], 100 * 430 / 590)
  expect_match(.dv_sb_prep(tr2, "weight")$tree$hovertext[1], "Read share")
  expect_error(dv_spec(predator = "p", stomach = "s", prey_name = "n",
                       weight_type = "rra"), "needs the `weight` column")
})

test_that("samples without reads are reported", {
  d <- data.frame(pred = "seal", sample = c("S1", "S2"), prey = "A",
                  reads = c(5, 0), phylum = "Chordata")
  spec <- dv_spec(predator = "pred", stomach = "sample", prey_name = "prey",
                  weight = "reads", weight_type = "rra", ranks = "phylum")
  expect_warning(dv_prepare(d, spec, taxonomy = "columns", verbose = FALSE),
                 "have no reads")
})

test_that("the default weight type keeps the mass labels", {
  d <- data.frame(pred = "cod", st = "s1", prey = "A", w = 2, phylum = "Chordata")
  spec <- dv_spec(predator = "pred", stomach = "st", prey_name = "prey", weight = "w",
                  ranks = "phylum")
  expect_equal(spec$weight_type, "mass")
  tr <- dv_tree(dv_prepare(d, spec, taxonomy = "columns", verbose = FALSE))
  expect_match(.dv_sb_prep(tr, "weight")$tree$hovertext[1], "Weight share")
})
