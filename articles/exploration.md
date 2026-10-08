# Exploring and aggregating diet data

Before a diet is displayed it is explored, and before it is explored the
reporting resolution has to be chosen. This article covers the functions
that serve those two steps: a small set of descriptive explorers, and a
resolution-robust aggregator. Everything here runs offline on the
bundled example data.

``` r

library(DietView)

csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))

spec <- dv_spec(
  predator   = "predator_species_common_name",
  stomach    = "stomach_id",
  prey_id    = "aphia_id",
  prey_name  = "verified_name",
  weight     = "prey_weight",
  count      = "number_of_prey",
  digestion  = "digestion_level_id",
  covariates = c("period", "size_class", "region")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
```

## 1. Describe the sample first

[`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
answers the questions you ask before anything else: how many stomachs
and records each predator contributed, how many distinct prey taxa were
seen, and the mean prey records per stomach. Pass `by` to break it down
by a covariate.

``` r

dv_summary(prep)
#>   predator_species_common_name n_stomachs n_records n_taxa prey_per_stomach
#> 1                 Atlantic cod          4        10      8              2.5
#> 2              Winter flounder          4         8      5              2.0
#> 3                      Alewife          3         6      4              2.0
#>   total_weight
#> 1      76.0000
#> 2       1.1120
#> 3       0.0848
dv_summary(prep, by = "region")
#>   predator_species_common_name            region n_stomachs n_records n_taxa
#> 1                      Alewife    Northumberland          2         3      2
#> 2                 Atlantic cod Magdalen Shallows          2         5      4
#> 3                 Atlantic cod    Northumberland          2         5      5
#> 4              Winter flounder Magdalen Shallows          2         4      3
#> 5              Winter flounder    Northumberland          2         4      3
#> 6                      Alewife Magdalen Shallows          1         3      3
#>   prey_per_stomach total_weight
#> 1              1.5       0.0038
#> 2              2.5      47.8000
#> 3              2.5      28.2000
#> 4              2.0       0.3500
#> 5              2.0       0.7620
#> 6              3.0       0.0810
```

A long prey-record table holds only non-empty stomachs, so there is no
vacuity (percent-empty) column – that has to come from the full sampling
frame upstream.

## 2. Is the diet adequately sampled?

[`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
builds the cumulative prey curve: prey richness against the number of
stomachs, averaged over random stomach orderings. A curve that flattens
means more stomachs would reveal little new; a still-rising curve is a
warning.

``` r

acc <- dv_prey_accumulation(prep, permutations = 50, seed = 1)
acc
#>    n_stomachs mean_richness sd_richness
#> 1           1          2.06   0.6197432
#> 2           2          3.96   0.9026039
#> 3           3          5.66   1.0993505
#> 4           4          7.32   1.3618715
#> 5           5          8.70   1.3439206
#> 6           6         10.06   1.3000785
#> 7           7         11.14   1.3094632
#> 8           8         12.10   1.1994897
#> 9           9         12.90   1.0151907
#> 10         10         13.48   0.7068181
#> 11         11         14.00   0.0000000

plot(acc$n_stomachs, acc$mean_richness, type = "b",
     xlab = "Stomachs examined", ylab = "Cumulative prey taxa",
     main = "Prey accumulation (pooled)")
```

![](exploration_files/figure-html/accumulation-1.png)

Pass `by = spec$predator` for one curve per predator. Keep
`permutations` modest while exploring; raise it for a figure.

## 3. Frequency of occurrence, the classical way

[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
gives `pct_occ`, a share of prey *records* that is additive so it can be
drawn as a sunburst. That is **not** the classical frequency of
occurrence.
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
computes the real percent-F – the share of non-empty stomachs containing
each taxon – independently at each rank, which is the nested-hierarchy
layout recommended for cross-study comparison (Buckland et al., 2017).

``` r

dv_fo_table(prep, rank = "class")
#>    rank        taxon n_stomachs n_total pct_fo
#> 1 class Malacostraca          7      11  63.64
#> 2 class     Copepoda          3      11  27.27
#> 3 class    Teleostei          3      11  27.27
#> 4 class     Bivalvia          2      11  18.18
#> 5 class           NA          2      11  18.18
#> 6 class   Polychaeta          2      11  18.18
```

These values are non-additive across ranks on purpose: a parent’s
percent-F is recomputed from stomach presence, not summed from its
children. Leave `rank = NULL` to stack every rank, and pass `by` for a
covariate breakdown.

## 4. Resolution-robust aggregation

Keeping the finest rank with explicit NA is the default, but a diet is
only comparable across studies if the reporting resolution is a stated,
reproducible choice rather than an analyst’s habit.
[`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
collapses prey seen in fewer than `threshold` stomachs into their
parent, walking up the hierarchy until every retained category clears
the threshold.

``` r

agg <- dv_aggregate_threshold(prep, threshold = 3)
table(agg$data$prey_rank, useNA = "ifany")
#> 
#>   class kingdom   order    <NA> 
#>       9       4       9       2
```

The returned object is a pruned `dietview_prep`: ranks finer than the
settled rank are set to NA, so it drops straight back into the normal
pipeline, and the sunburst then has no leaf rarer than the threshold.

``` r

tree <- dv_build_tree(agg$data, agg$ranks, weight_col = spec$weight)
dv_rank_table(tree, "Class")
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 8  Malacostraca          3        11 45.833333 39.7600 51.504725584
#> 7      Copepoda          1         4 16.666667  0.0048  0.006217874
#> 10           NA          1         4 16.666667  0.7320  0.948225833
#> 9     Teleostei          1         3 12.500000 35.1000 45.468205936
#> 11           NA          1         2  8.333333  1.6000  2.072624772
```

Three architectures, two arguments:

``` r

dv_aggregate_threshold(prep, 100)                      # pooled (primary)
dv_aggregate_threshold(prep, 100, min_predators = 2)   # pooled cross-predator
dv_aggregate_threshold(prep, 50, scope = "per_predator")
```

To reproduce the “resolutions” bookkeeping – how category count responds
to the threshold – sweep it:

``` r

dv_threshold_sweep(prep, thresholds = c(2, 3, 5, 8))
#>   threshold n_categories n_records
#> 1         2           10        24
#> 2         3            6        24
#> 3         5            4        24
#> 4         8            2        24
# the paper's grids: seq(10, 1000, 10) -> 100 resolutions;
#                    seq(5, 250, 5) per_predator -> 50 resolutions
```

Reporting a statistic as a mean across resolutions is done in the
analysis that consumes these; DietView only produces the aggregation,
not the test.

## 5. Handoff to multivariate analysis

[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
reshapes records into the sampling-unit by prey-category matrix that
ordination, PERMANOVA and compositional regression expect. If you
aggregated first, it uses the `prey_category` column automatically.

``` r

m <- dv_matrix(agg, currency = "occurrence")
dim(m)
#> [1] 11  7
m[1:3, 1:min(5, ncol(m))]
#>       Amphipoda Animalia Copepoda Decapoda Malacostraca
#> AW001         0        0        2        0            0
#> AW002         0        0        1        0            0
#> AW003         1        0        1        0            1
```

`currency` is `"weight"` (summed mass), `"occurrence"` (record counts)
or `"fo"` (presence per unit). Use `unit` to aggregate to something
coarser than a stomach, such as a trawl set, and `include_na = FALSE` to
drop the unidentified column for a clean analysis matrix.

``` r

# DietView stops here; the analysis lives in your own tooling
mm <- vegan::decostand(m, "total")
d  <- vegan::vegdist(mm, "bray")
# vegan::adonis2(d ~ period, data = set_covariates)
```

## Where this fits

These functions cover the exploration and aggregation layers. Inference
– diversity tests, PERMANOVA, dispersion, classification of change – is
deliberately left to the packages built for it;
[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
is the bridge to them.
