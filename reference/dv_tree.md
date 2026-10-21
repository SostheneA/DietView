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
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
tree <- dv_tree(prep)                          # shares of prey records
dv_rank_table(tree, "Class")
#>            label value_item value_occ     pct_occ    value_w        pct_w
#> 23  Malacostraca         92      2085 24.44314185  2948.8905 1.346632e+01
#> 29     Teleostei         64      1614 18.92145369 14366.4605 6.560545e+01
#> 47            NA          1      1553 18.20633060  1115.2120 5.092694e+00
#> 20    Polychaeta         30       758  8.88628370   584.2752 2.668134e+00
#> 30            NA          1       713  8.35873388  1328.6695 6.067463e+00
#> 25            NA          1       662  7.76084408   501.2407 2.288951e+00
#> 36   Ophiuroidea          4       493  5.77960141   526.9670 2.406432e+00
#> 38      Bivalvia         12       317  3.71629543   231.8770 1.058883e+00
#> 40    Gastropoda          3        72  0.84407972    26.4690 1.208725e-01
#> 37            NA          1        67  0.78546307    26.1870 1.195848e-01
#> 39   Cephalopoda          7        48  0.56271981    89.2940 4.077673e-01
#> 35    Echinoidea          2        31  0.36342321    49.9250 2.279860e-01
#> 22      Copepoda          3        30  0.35169988     0.4480 2.045823e-03
#> 21            NA          1        23  0.26963658    12.0040 5.481711e-02
#> 34    Asteroidea          1        11  0.12895662     1.0410 4.753800e-03
#> 41            NA          1        10  0.11723329    11.1470 5.090356e-02
#> 43     Trematoda          1        10  0.11723329     0.0110 5.023227e-05
#> 28        Myxini          1         7  0.08206331    24.6800 1.127030e-01
#> 45            NA          2         7  0.08206331    39.4100 1.799685e-01
#> 44            NA          1         4  0.04689332     0.3750 1.712464e-03
#> 19      Gephyrea          1         3  0.03516999     4.2900 1.959059e-02
#> 24   Thecostraca          1         2  0.02344666     0.3400 1.552634e-03
#> 26            NA          1         2  0.02344666     0.5100 2.328951e-03
#> 18    Clitellata          1         1  0.01172333     0.0700 3.196599e-04
#> 27   Leptocardii          1         1  0.01172333     0.2970 1.356271e-03
#> 31  Hexacorallia          1         1  0.01172333     1.5320 6.995986e-03
#> 32      Hydrozoa          1         1  0.01172333     6.5000 2.968271e-02
#> 33            NA          1         1  0.01172333     0.0010 4.566570e-06
#> 42 Hoplonemertea          1         1  0.01172333     0.0010 4.566570e-06
#> 46  Phaeophyceae          1         1  0.01172333     0.0000 0.000000e+00
#> 48            NA          1         1  0.01172333     0.1480 6.758524e-04
# %N from prey_count; records without a count are left out, with a warning
tree_n <- suppressWarnings(dv_tree(prep, currency = "numbers"))
```
