# Build a sampling-unit by prey-category matrix

Reshapes the records into a unit x category matrix - the standard input
to multivariate diet analysis (ordination, PERMANOVA, compositional
regression). Rows are the sampling unit (stomachs by default, or any
coarser unit such as a trawl set), columns are prey categories, and
cells carry the chosen currency. DietView does not run those analyses;
this is the handoff to the tools that do.

## Usage

``` r
dv_matrix(
  prep,
  category = NULL,
  unit = NULL,
  rank = NULL,
  currency = c("weight", "occurrence", "fo"),
  include_na = TRUE
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- category:

  Column giving the prey category. Defaults to `prey_category` (from
  [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md))
  if present, otherwise the finest resolved rank label. Ignored when
  `rank` is given.

- unit:

  Column giving the sampling unit. Defaults to the spec's stomach.

- rank:

  Optional rank (one of `prep$ranks`, e.g. `"class"`): columns are then
  the taxa at that rank, plus the unidentified column (`"NA"`) when
  `include_na = TRUE`.

- currency:

  `"weight"` (summed mass), `"occurrence"` (record counts), or `"fo"`
  (presence/absence, one per unit).

- include_na:

  Keep an explicit unidentified column.

## Value

A numeric matrix with `unit` row names and category column names.

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
m <- dv_matrix(prep, currency = "occurrence")
dim(m)
#> [1] 11 15
dv_matrix(prep, rank = "class", currency = "weight")
#>       Bivalvia Copepoda Malacostraca  NA Polychaeta Teleostei
#> AW001    0.000    3e-03         0.00 0.0      0.000       0.0
#> AW002    0.000    8e-04         0.00 0.0      0.000       0.0
#> AW003    0.000    1e-03         0.08 0.0      0.000       0.0
#> GM001    0.000    0e+00        14.30 0.0      0.000       5.1
#> GM002    0.000    0e+00         0.80 0.0      0.000       8.0
#> GM003    0.000    0e+00         9.30 1.5      0.000       0.0
#> GM004    0.000    0e+00        15.00 0.0      0.000      22.0
#> WF001    0.009    0e+00         0.00 0.0      0.503       0.0
#> WF002    0.000    0e+00         0.05 0.0      0.200       0.0
#> WF003    0.020    0e+00         0.00 0.1      0.000       0.0
#> WF004    0.000    0e+00         0.23 0.0      0.000       0.0
# vegan::decostand(m, "total"); vegan::vegdist(m, "bray")
```
