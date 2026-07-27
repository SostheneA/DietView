# Launch the interactive DietView app

A Shiny explorer over a prepared dataset: pick a predator (or "(all
predators)" to pool every predator together), a mode (occurrence counts
/ occurrence % / weight %), and optionally one covariate to facet by
plus a second one to cross it with (e.g. length bins by period). Shows
the sunburst – one panel per covariate cell when faceting – plus the
within-rank importance table for the current selection.

## Usage

``` r
run_dietview(prep, ...)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Runs the app (does not return).

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
if (interactive()) {
  run_dietview(prep)
}
```
