# Count diet categories across a sweep of thresholds

Runs
[`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
over a vector of thresholds and reports how many prey categories each
one yields. This reproduces the "resolutions" bookkeeping of
resolution-robust diet analysis (e.g. thresholds 10-1000 by 10 give 100
resolutions; a per-predator sweep of 5-250 by 5 gives 50), so downstream
summaries can be reported as a mean +/- SD across resolutions.

## Usage

``` r
dv_threshold_sweep(
  prep,
  thresholds,
  scope = c("pooled", "per_predator"),
  min_predators = 1L
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- thresholds:

  A numeric vector of thresholds, e.g. `seq(10, 1000, 10)`.

- scope, min_predators:

  Passed to
  [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md).

## Value

A data.frame with `threshold`, `n_categories` and `n_records`.

## Details

This function only counts categories; it does not compute diet indices
or run any statistical test. Those belong in the analysis that consumes
the per-resolution `prey_category` column, not in DietView.

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
dv_threshold_sweep(prep, thresholds = c(2, 3, 5, 8))
#>   threshold n_categories n_records
#> 1         2           10        24
#> 2         3            6        24
#> 3         5            4        24
#> 4         8            2        24
```
