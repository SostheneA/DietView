# Frequency of occurrence per rank (the Buckland Table B1 layout)

The classical frequency of occurrence (percent-F): the proportion of
non-empty stomachs that contain each taxon, computed INDEPENDENTLY at
each taxonomic rank. Because a stomach can contain several categories,
and because a parent's percent-F is recomputed from stomach presence
rather than summed from its children, these values are non-additive
across ranks - which is exactly why they are reported as a nested
hierarchy of levels (Buckland et al., 2017). This is distinct from the
within-rank record share in
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
(`pct_occ`), which is additive so that it can be drawn as a sunburst.

## Usage

``` r
dv_fo_table(prep, rank = NULL, by = NULL, include_na = TRUE)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- rank:

  A single rank (e.g. `"genus"`) or `NULL` for every rank stacked.

- by:

  Optional covariate to compute percent-F within each level of.

- include_na:

  Keep the explicit unidentified category at each rank.

## Value

A data.frame with (optional) `by`, `rank`, `taxon`, `n_stomachs`
(stomachs containing the taxon), `n_total` (stomachs in the group), and
`pct_fo`.

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
dv_fo_table(prep, rank = "class")
#>    rank        taxon n_stomachs n_total pct_fo
#> 1 class Malacostraca          7      11  63.64
#> 2 class     Copepoda          3      11  27.27
#> 3 class    Teleostei          3      11  27.27
#> 4 class     Bivalvia          2      11  18.18
#> 5 class           NA          2      11  18.18
#> 6 class   Polychaeta          2      11  18.18
```
