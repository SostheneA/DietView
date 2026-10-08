# Prey accumulation (cumulative prey) curve for sample sufficiency

Prey richness as a function of the number of stomachs examined, averaged
over random stomach orderings. When the curve approaches an asymptote
the diet has been adequately sampled; a still-rising curve warns that
more stomachs would reveal more prey (Ferry and Cailliet, 1996). This is
a descriptive sufficiency diagnostic, not a statistical test.

## Usage

``` r
dv_prey_accumulation(prep, by = NULL, permutations = 100, seed = NULL)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional column giving one curve per group (e.g. the predator). `NULL`
  pools all records into a single curve.

- permutations:

  Number of random stomach orderings to average over.

- seed:

  Optional integer for reproducibility.

## Value

A data.frame with (optional) group column, `n_stomachs`, `mean_richness`
and `sd_richness`.

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
acc <- dv_prey_accumulation(prep, permutations = 20, seed = 1)
head(acc)
#>   n_stomachs mean_richness sd_richness
#> 1          1          2.00   0.6488857
#> 2          2          4.05   0.9445132
#> 3          3          5.70   1.0809353
#> 4          4          7.25   1.3327850
#> 5          5          8.55   1.3562720
#> 6          6          9.95   1.1909748
# plot(acc$n_stomachs, acc$mean_richness, type = "b")
```
