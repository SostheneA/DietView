# Importance table for one rank

Convenience wrapper returning the within-rank importance for a single
rank (e.g. "Class"), sorted by occurrence share, the NA row included.

## Usage

``` r
dv_rank_table(tree, rank)
```

## Arguments

- tree:

  A `dietview_tree` (or a data.frame from
  [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)).

- rank:

  Rank label to extract (e.g. "Class").

## Value

A data.frame: `label, value_item, value_occ, pct_occ, value_w, pct_w`.

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
                weight = "prey_weight")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
#> No digestion column: digestion diagnostics disabled.
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
dv_rank_table(tree, "Class")
#>           label value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca        11 45.833333 39.7600 51.504725584
#> 9      Copepoda         4 16.666667  0.0048  0.006217874
#> 11    Teleostei         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia         2  8.333333  0.0290  0.037566324
#> 13           NA         2  8.333333  1.6000  2.072624772
```
