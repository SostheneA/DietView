# Build the diet tree from a prepared dataset, using the columns in its spec

The one way vignettes, the dashboard and the Shiny app build a tree, so
that one spec always gives the same numbers. By default each record
counts once (shares of prey records), even when the spec declares a
`count` column; ask for `currency = "numbers"` to count individuals
instead.

## Usage

``` r
dv_tree(prep, currency = c("records", "numbers"))
```

## Arguments

- prep:

  A `dietview_prep`.

- currency:

  `"records"` (each record counts once) or `"numbers"` (each record
  counts its `count` column; needs `count` in the spec). Records with an
  empty count, such as unidentified material, contribute 0 to the
  numbers currency, with a warning.

## Value

A `dietview_tree`, as from
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md).

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id", prey_id = "aphia_id",
                prey_name = "verified_name", weight = "prey_weight",
                count = "number_of_prey")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
tree <- dv_tree(prep)                       # shares of prey records
dv_rank_table(tree, "Class")
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca          7        11 45.833333 39.7600 51.504725584
#> 9      Copepoda          2         4 16.666667  0.0048  0.006217874
#> 11    Teleostei          3         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta          1         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia          1         2  8.333333  0.0290  0.037566324
#> 13           NA          1         2  8.333333  1.6000  2.072624772
tree_n <- suppressWarnings(dv_tree(prep, currency = "numbers"))   # %N
```
