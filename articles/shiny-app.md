# The interactive Shiny explorer

[`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
opens an interactive [Shiny](https://shiny.posit.co/) app on a prepared
dataset. Use it to explore a diet on your own machine before you fix the
figures you will report. The chunks here are shown but not run, because
the app needs an interactive R session, the `shiny` package and, for the
table, `DT`.

``` r

install.packages(c("shiny", "DT"))
```

``` r

library(DietView)

dat <- read.csv(system.file("extdata", "dietview_example.csv", package = "DietView"),
                na.strings = c("NA", ""))
lin <- read.csv(system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
                na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name", stomach = "stomach_id",
                prey_id = "aphia_id", prey_name = "verified_name",
                weight = "prey_weight", digestion = "digestion_level_id",
                covariates = c("period", "size_class", "size_bin", "region"))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin)

run_dietview(prep)
```

## What the app offers

- a predator selector, with “(all predators)” to pool every predator;
- a choice of what sizes the wedges: prey records (% of all records),
  weight (% of total weight) or the number of distinct prey items;
- a covariate to facet by, which draws one sunburst per level;
- a second covariate to cross with the first, which draws one sunburst
  per combination of levels;
- a rank selector for the table under the figure.

For each selection the app takes the records of the chosen predator,
builds the tree with
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
draws the sunburst with one palette built from all the records, and
shows the table for the chosen rank: one row per taxon at that rank,
with its records, weight and shares.

## The app or the dashboard?

Use the app to explore on your own machine. Use
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
or
[`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
to write a single HTML file that you can archive, email or put on a web
server, and that the reader opens without R.
