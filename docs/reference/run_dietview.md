# Launch the interactive DietView app

A Shiny explorer over a prepared dataset: pick a predator (or "(all
predators)" to pool every predator together), what sizes the wedges
(prey records as % of all records, weight as % of total weight, or the
number of distinct prey items), the reporting resolution, and optionally
one covariate to facet by plus a second one to cross it with (e.g.
length bins by period).

## Usage

``` r
run_dietview(prep, currency = c("records", "numbers"), ...)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- currency:

  `"records"` (default: each record counts once) or `"numbers"` (each
  record counts its `count` column, %N; needs `count` in the spec). See
  [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md).

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Runs the app (does not return).

## Details

The reporting resolution is either the full hierarchy (every record at
every rank, unidentified material carried outward) or one of the three
threshold aggregations of
[`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md):
pooled, pooled cross-predator (a category must also span `min_predators`
predators) and per predator. Pooled aggregations are computed on all
predators before one is selected, so the categories are the same in
every predator's view.

The tabs show the sunburst (one panel per covariate cell when faceting,
covariate `NA` values getting their own "NA" panel), the rank table, the
frequency of occurrence at the chosen rank, the digestion diagnostic
(when a digestion column is declared) and a "Reproduce" tab. That tab
shows the R script that rebuilds the current view with exported
functions only (see
[`dv_script()`](https://sosthenea.github.io/DietView/reference/dv_script.md))
and offers the script, the prepared data it reads and the current tables
as downloads.

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
if (interactive()) {
  run_dietview(prep)
}
```
