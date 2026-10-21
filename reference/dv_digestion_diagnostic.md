# Identification resolution versus digestion level

Quantifies the identification bias linked to digestion: for each
digestion level, the share of records (and of weight) whose finest
resolved rank is Kingdom, Phylum, ... Species, or unresolved. As
digestion advances, mass shifts toward the coarse ranks – this makes the
bias explicit instead of hiding it inside a functional grouping.

## Usage

``` r
dv_digestion_diagnostic(prep, by = NULL)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional covariate to split the diagnostic by (e.g. "period").

## Value

A data.frame with columns `digestion`, optional `by`, `finest_rank`,
`n_records`, `p_records`, `weight`, `p_weight`.

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id",
                prey_id = "aphia_id",
                prey_name = "verified_name",
                weight = "prey_weight", digestion = "digestion_level_id")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
head(dv_digestion_diagnostic(prep))
#>   digestion finest_rank n_records  weight p_records    p_weight
#> 1         1     Species         2  9.0020 100.00000 100.0000000
#> 2         2       Class         3  0.5128  33.33333   1.4334914
#> 3         2       Order         2  0.1100  22.22222   0.3074962
#> 4         2     Species         4 35.1500  44.44444  98.2590124
#> 5         3       Class         2  0.2010  28.57143   0.9662997
#> 6         3       Order         2  0.4500  28.57143   2.1633575
```
