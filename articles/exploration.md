# Exploring and aggregating diet data

This article covers the functions you use before drawing a diet: a few
descriptive summaries, a prey accumulation curve, the classical
frequency of occurrence, aggregation of rare prey to a stated threshold,
and export of a stomach-by-prey matrix. Everything runs offline on the
invented example table that ships with the package (24 prey records from
11 stomachs), so the numbers show what each function returns, not what
these fish eat.

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
  digestion  = "digestion_level_id",
  covariates = c("period", "size_class", "region")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
```

## 1. Describe the sample first

[`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
gives, for each predator, the number of stomachs and prey records, the
number of distinct prey taxa and the mean number of records per stomach.
Pass `by` to break it down by a covariate.

``` r

dv_summary(prep)
#>   predator_species_common_name n_stomachs n_records n_taxa records_per_stomach
#> 1                 Atlantic cod          4        10      8                 2.5
#> 2              Winter flounder          4         8      5                 2.0
#> 3                      Alewife          3         6      4                 2.0
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
#>   records_per_stomach total_weight
#> 1                 1.5       0.0038
#> 2                 2.5      47.8000
#> 3                 2.5      28.2000
#> 4                 2.0       0.3500
#> 5                 2.0       0.7620
#> 6                 3.0       0.0810
```

Taxa are the finest names reached, so “Amphipoda” and *Themisto
libellula* count as two even though the second is an amphipod. Read the
taxa count as the number of distinct prey names, not as species
richness.

A table of prey records holds only stomachs that contained something, so
it cannot give the share of empty stomachs. That has to come from the
full list of stomachs examined.

## 2. Is the diet adequately sampled?

[`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
builds the cumulative prey curve: the number of prey taxa found against
the number of stomachs examined, averaged over random orders of the
stomachs. A curve that levels off means more stomachs would add few new
taxa; a curve still rising means the sample is not yet enough.

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
     main = "Prey accumulation (all predators)")
```

![](exploration_files/figure-html/accumulation-1.png)

As in
[`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md),
taxa are the finest names reached, which inflates the curve when
identification depth varies. Use `rank = "family"` for a curve at one
stated rank. Pass `by = spec$predator` for one curve per predator. Keep
`permutations` low while exploring and raise it for a figure.

## 3. Frequency of occurrence (%FO)

[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
gives `pct_occ`, the share of prey records. Shares of records add up
across the ranks, which is what lets them be drawn as a sunburst, but
they are not the frequency of occurrence of the diet literature.
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
computes %FO: the share of non-empty stomachs that contain each taxon,
computed separately at each rank, as recommended for comparison between
studies (Buckland et al., 2017).

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

%FO does not add up across ranks: a parent’s %FO is computed from the
stomachs that contain it, not summed from its children. Leave
`rank = NULL` to stack every rank, and pass `by` for a breakdown by
covariate.

## 4. Aggregating rare prey to a stated threshold

By default DietView keeps each record at the deepest rank it reached. To
make the reporting resolution a stated choice,
[`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
moves prey found in fewer than `threshold` stomachs up to their parent,
and repeats up the hierarchy until every category it reports occurs in
at least `threshold` stomachs.

``` r

agg <- dv_aggregate_threshold(prep, threshold = 3)
table(agg$data$prey_category, useNA = "ifany")
#> 
#>        Amphipoda Animalia (other)         Copepoda         Decapoda 
#>                5                6                4                4 
#>        Teleostei             <NA> 
#>                3                2
table(agg$data$prey_rank, useNA = "ifany")
#> 
#>   class kingdom   order    <NA> 
#>       7       6       9       2
```

A category named after a taxon that also has retained descendants holds
only the records that stayed at that taxon, and its label ends in
“(other)”. Here “Animalia (other)” holds the bivalve, polychaete and
mysid records: none of those groups reaches 3 stomachs on its own, so
they move up until they are counted together, at kingdom. The records
with no prey placement at all stay unidentified (`NA`).

The result is a `dietview_prep` again: ranks finer than the rank each
record settled at are set to `NA`, so it goes straight back into the
usual functions, and the sunburst then has no category rarer than the
threshold.

``` r

tree <- dv_build_tree(agg$data, agg$ranks, weight_col = spec$weight)
dv_rank_table(tree, "Class")
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 8  Malacostraca          2         9 37.500000 39.5800 51.271555298
#> 10           NA          1         6 25.000000  0.9120  1.181396120
#> 7      Copepoda          1         4 16.666667  0.0048  0.006217874
#> 9     Teleostei          1         3 12.500000 35.1000 45.468205936
#> 11           NA          1         2  8.333333  1.6000  2.072624772
```

Two arguments give three ways of counting:

``` r

dv_aggregate_threshold(prep, 100)                      # all predators pooled
dv_aggregate_threshold(prep, 100, min_predators = 2)   # pooled, and in at least 2 predators
dv_aggregate_threshold(prep, 50, scope = "per_predator")
```

To see how the number of categories changes with the threshold, sweep
it:

``` r

dv_threshold_sweep(prep, thresholds = c(2, 3, 5, 8))
#>   threshold n_categories pct_coarser
#> 1         2           10          75
#> 2         3            5         100
#> 3         5            3         100
#> 4         8            2         100
```

DietView stops at the aggregation. If you summarize a statistic across
several thresholds, do it in your own analysis.

## 5. Handing over to multivariate analysis

[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
turns the records into the stomach-by-prey matrix that ordination,
PERMANOVA and compositional regression expect. If you aggregated first,
it uses the `prey_category` column automatically. Pass `rank` to build
the matrix at one rank instead.

``` r

m <- dv_matrix(agg, currency = "occurrence")
dim(m)
#> [1] 11  6
m[1:3, 1:min(5, ncol(m))]
#>       Amphipoda Animalia (other) Copepoda Decapoda NA
#> AW001         0                0        2        0  0
#> AW002         0                0        1        0  0
#> AW003         1                1        1        0  0
```

`currency` is `"weight"` (summed weight), `"occurrence"` (number of
records) or `"fo"` (presence or absence in each unit). Use `unit` to sum
over something coarser than a stomach, such as a trawl set. Use
`include_na = FALSE` to drop the unidentified column, and say in your
methods that you did.

``` r

# DietView stops here; the analysis uses other packages
mm <- vegan::decostand(m, "total")
d  <- vegan::vegdist(mm, "bray")
# vegan::adonis2(d ~ period, data = set_covariates)
```

## Where this fits

These functions describe and aggregate. DietView does not test
hypotheses: diversity tests, PERMANOVA and dispersion analyses belong to
packages built for them, and
[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
is the step that hands your data over.

## Reference

Buckland, A., Baker, R., Loneragan, N., & Sheaves, M. (2017).
Standardising fish stomach content analysis: the importance of prey
condition. *Fisheries Research*, 196, 126–140.
