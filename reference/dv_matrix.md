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
  if present, otherwise the finest resolved rank label.

- unit:

  Column giving the sampling unit. Defaults to the spec's stomach.

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
#> No digestion column: digestion diagnostics disabled.
m <- dv_matrix(prep, currency = "occurrence")
dim(m)
#> [1] 11 15
# vegan::decostand(m, "total"); vegan::vegdist(m, "bray")
```
