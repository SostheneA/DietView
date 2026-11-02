# Write a reproducible R script for one DietView analysis

Turns the choices behind a view (predator, currency, reporting
resolution, stratifying covariates and table rank) into a plain R script
that rebuilds it with exported DietView functions only. The Shiny
application
([`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md))
uses it for its "Reproduce" tab, so a figure explored interactively can
be archived and rerun without the application.

## Usage

``` r
dv_script(
  prep,
  predator = NULL,
  mode = c("occurrence", "weight", "count"),
  currency = c("records", "numbers"),
  aggregation = NULL,
  facet = NULL,
  rank = NULL,
  data_file = "dietview_prep.rds",
  file = NULL
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- predator:

  A predator to keep, or `NULL` (default) for all predators.

- mode:

  What sizes the wedges: `"occurrence"` (prey records, or individuals
  with `currency = "numbers"`), `"weight"` or `"count"` (distinct prey
  items). See
  [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md).

- currency:

  `"records"` or `"numbers"`. See
  [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md).

- aggregation:

  `NULL` (default: the full hierarchy, every record at every rank) or a
  list with `threshold` and, optionally, `scope` and `min_predators`,
  passed to
  [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md).

- facet:

  Up to two covariates to draw one panel per level (or per combination
  of levels), or `NULL`.

- rank:

  Rank for the rank table and the frequency-of-occurrence table.
  Defaults to the third rank of `prep`.

- data_file:

  File name the script reads `prep` from.

- file:

  Optional path; if given, the script is written there.

## Value

A character vector of script lines, of class `dietview_script`
(invisibly when `file` is given).

## Details

The script starts from the prepared data saved with
`saveRDS(prep, data_file)`, so it does not depend on the network or on
the state of WoRMS. Its header records the DietView and R versions, the
date, the taxonomy source (with the `worrms` version and retrieval date
when the lineage came from WoRMS) and the column specification.

## Examples

``` r
prep <- dv_prepare(
  ices_diet[ices_diet$predator_common == "Atlantic cod", ],
  dv_spec(predator = "predator_common", stomach = "stomach_id",
          prey_id = "prey_aphia_id", prey_name = "prey_name",
          weight = "prey_weight_g", covariates = "quarter"),
  taxonomy = "table", lineage = ices_lineage, verbose = FALSE)
s <- dv_script(prep, mode = "weight",
               aggregation = list(threshold = 10, scope = "pooled"))
s
#> ## DietView analysis script
#> ## Generated 2026-11-02 17:17 UTC with DietView 0.1.0 and R version 4.6.2 (2026-10-29).
#> ## Predator: all predators | wedges: weight | currency: records
#> ## Reporting resolution: threshold 10 stomachs, scope = pooled, min_predators = 1
#> # Taxonomy source: table
#> # Column specification of the prepared data:
#> #   predator = "predator_common"
#> #   stomach = "stomach_id"
#> #   prey_id = "prey_aphia_id"
#> #   prey_name = "prey_name"
#> #   weight = "prey_weight_g"
#> #   covariates = "quarter"
#> #   ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species")
#> 
#> library(DietView)
#> 
#> ## 1. Prepared data (save it from R with saveRDS(prep, "dietview_prep.rds"))
#> prep <- readRDS("dietview_prep.rds")
#> spec <- prep$spec
#> prep
#> 
#> ## 2. Reporting resolution: rare prey merged up their lineage
#> ## (applied before selecting a predator, so pooled counts use all predators)
#> prep <- dv_aggregate_threshold(prep, threshold = 10, scope = "pooled", min_predators = 1)
#> attr(prep, "aggregation")
#> 
#> ## 4. Multi-rank tree and sunburst
#> tree <- dv_build_tree(prep$data, prep$ranks, weight_col = "prey_weight_g", count_col = NULL)
#> pal <- dv_palette_tree(tree)   # one palette for every panel
#> dv_sunburst(tree, mode = "weight", colors = pal, title = "All predators")
#> 
#> ## 6. Tables behind the figure
#> dv_rank_table(tree, "Class")
#> dv_fo_table(prep, rank = "class")
#> 
#> sessionInfo()
```
