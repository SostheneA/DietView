# Aggregate rare prey upward to a stomach-frequency threshold

Collapses prey that occur in fewer than `threshold` stomachs into their
parent taxon, walking up the taxonomic hierarchy until every retained
category meets the threshold. This is the threshold-based,
resolution-robust aggregation used when a diet description must be
stable to the choice of reporting rank (Buckland et al., 2017; Pombo et
al., 2013; Bevilacqua et al., 2012): each record settles at the deepest
ancestor whose subtree is sampled widely enough, and finer, rarely seen
taxa are merged upward rather than dropped.

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
  a given rank (the paper's `x`).

- scope:

  `"pooled"` (counts across the dataset) or `"per_predator"` (counts
  within each predator).

- min_predators:

  Minimum number of distinct predators a category's subtree must span to
  be retained. Ignored (forced to 1) when `scope = "per_predator"`. Set
  to 2 for the cross-predator variant.

- other_label:

  Label for records that do not reach the threshold even at the coarsest
  rank; defaults to `paste0("other ", <coarsest rank>)`.

## Value

A `dietview_prep` with pruned taxonomy columns and the added
`prey_category` / `prey_rank` columns. Feed it to
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
exactly as you would the output of
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

## Details

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
stomachs. A convenience column `prey_category` (the settled label) and
`prey_rank` (the rank it settled at) are added, so the result can also
feed a flat set x category matrix.

## See also

[`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.md)
to run this across many thresholds.

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id", prey_id = "aphia_id",
                prey_name = "verified_name", weight = "prey_weight")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
#> No digestion column: digestion diagnostics disabled.

# retain only taxa seen in >= 3 stomachs; rarer prey merge upward
agg <- dv_aggregate_threshold(prep, threshold = 3)
table(agg$data$prey_rank, useNA = "ifany")
#> 
#>   class kingdom   order    <NA> 
#>       9       4       9       2 

# the pruned prep drops straight into the usual pipeline
tree <- dv_build_tree(agg$data, agg$ranks, weight_col = spec$weight)
head(dv_rank_table(tree, "Class"))
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 8  Malacostraca          3        11 45.833333 39.7600 51.504725584
#> 7      Copepoda          1         4 16.666667  0.0048  0.006217874
#> 10           NA          1         4 16.666667  0.7320  0.948225833
#> 9     Teleostei          1         3 12.500000 35.1000 45.468205936
#> 11           NA          1         2  8.333333  1.6000  2.072624772
```
