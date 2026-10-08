# Describe the sampled diet dataset

A quick overview of sample structure, computed before any figure: how
many stomachs and prey records each predator contributes, how many
distinct prey taxa were seen, and the mean number of prey records per
stomach. Optionally broken down by a covariate.

## Usage

``` r
dv_summary(prep, by = NULL)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional covariate column to break the summary down by.

## Value

A data.frame with one row per predator (and per `by` level), with
`n_stomachs`, `n_records`, `n_taxa`, `prey_per_stomach`, and, when a
weight column is declared, `total_weight`.

## Details

Note that a long prey-record table represents only non-empty stomachs,
so this function cannot report a vacuity (percent-empty) index; that
must be computed upstream from the full sampling frame.

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id", prey_id = "aphia_id",
                prey_name = "verified_name", weight = "prey_weight",
                covariates = "region")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
#> No digestion column: digestion diagnostics disabled.
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
