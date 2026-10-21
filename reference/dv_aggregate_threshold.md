# Aggregate rare prey upward to a stomach-frequency threshold

Collapses prey that occur in fewer than `threshold` stomachs into their
parent taxon, walking up the taxonomic hierarchy until every retained
category meets the threshold. This is a threshold-based aggregation in
the spirit of taxonomic sufficiency (Bevilacqua et al., 2012; Pombo et
al., 2013), for when a diet description must be stable to the choice of
reporting rank: finer, rarely seen taxa are merged upward rather than
dropped.

## Usage

``` r
dv_aggregate_threshold(
  prep,
  threshold,
  scope = c("pooled", "per_predator"),
  min_predators = 1L,
  other_label = NULL
)
```

## Arguments

- prep:

  A `dietview_prep` object from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- threshold:

  Minimum number of stomachs a category must occur in to be retained at
  a given rank.

- scope:

  `"pooled"` (counts across the dataset) or `"per_predator"` (counts
  within each predator).

- min_predators:

  Minimum number of distinct predators a category's subtree must span to
  be retained. Ignored (forced to 1) when `scope = "per_predator"`. Set
  to 2 for the cross-predator variant.

- other_label:

  Label for records that do not reach the threshold even at the coarsest
  rank; defaults to `"other (below threshold)"`.

## Value

A `dietview_prep` with pruned taxonomy columns and the added
`prey_category` / `prey_rank` columns. Feed it to
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
exactly as you would the output of
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

## Details

Each record first settles at the deepest ancestor whose whole subtree is
found in at least `threshold` stomachs. The category reported for a node
is its residual, the records that settled there and not deeper, so a
residual that itself falls below the threshold is moved up one more
rank, and so on until every reported category reaches `threshold`
stomachs (and `min_predators` predators). A residual whose node also has
retained descendants is labelled `"<taxon> (other)"` in `prey_category`,
for example `"Malacostraca (other)"` for malacostracans other than the
retained orders.

Three architectures are expressed through two arguments:

- **Pooled** (default): `scope = "pooled"`, `min_predators = 1`. Counts
  are taken across the whole dataset.

- **Pooled cross-predator**: `scope = "pooled"`, `min_predators = 2`. A
  category is retained only if its subtree also spans at least
  `min_predators` predator species.

- **Per-predator**: `scope = "per_predator"`. Counts are taken within
  each predator separately, so each predator gets its own tree.

The taxonomy columns of the returned object are pruned: for every
record, ranks finer than the settled rank are set to `NA`, so the
explicit-NA machinery of
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
shows the merge, and the sunburst has no leaf rarer than `threshold`
stomachs (apart from the records that were unidentified at every rank to
begin with, and the `other_label` group). A convenience column
`prey_category` (the settled label) and `prey_rank` (the rank it settled
at) are added, so the result can also feed a flat set x category matrix.

## See also

[`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.md)
to run this across many thresholds.

## Examples

``` r
# the standard set-up: public ICES data, non-food items and nematodes dropped
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
spec <- dv_spec(
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
# Atlantic cod only, for speed
cod <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)

# keep only taxa seen in >= 10 stomachs; rarer prey merge upward
agg <- dv_aggregate_threshold(prep_cod, threshold = 10)
table(agg$data$prey_rank, useNA = "ifany")
#> 
#>   class  family   genus kingdom   order  phylum species    <NA> 
#>     180     313     158      14     459     222     766     192 

# the pruned prep drops straight into the usual pipeline
tree <- dv_build_tree(agg$data, agg$ranks, weight_col = spec$weight)
head(dv_rank_table(tree, "Class"))
#>           label value_item value_occ   pct_occ  value_w      pct_w
#> 13 Malacostraca         17       999 43.359375 2286.830 22.3616241
#> 15    Teleostei         16       624 27.083333 7045.949 68.8983695
#> 22           NA          1       192  8.333333  123.520  1.2078326
#> 16           NA          1       154  6.684028  249.377  2.4385174
#> 12   Polychaeta          5       144  6.250000  380.515  3.7208421
#> 14           NA          1        68  2.951389   55.395  0.5416765
```
