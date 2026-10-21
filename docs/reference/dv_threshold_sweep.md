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

A data.frame with `threshold`, `n_categories` (number of prey
categories) and `pct_coarser` (percentage of all records whose category
is coarser than the finest rank, the unidentified and `other` records
included).

## Details

This function only counts categories; it does not compute diet indices
or run any statistical test. Those belong in the analysis that consumes
the per-resolution `prey_category` column, not in DietView.

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
dv_threshold_sweep(prep_cod, thresholds = c(2, 5, 10, 20))
#>   threshold n_categories pct_coarser
#> 1         2          104       62.28
#> 2         5           63       65.32
#> 3        10           47       66.75
#> 4        20           32       72.18
```
