# The interactive Shiny explorer

[`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
launches an interactive [Shiny](https://shiny.posit.co/) app over a
prepared dataset. It is the fastest way to explore a diet before
committing to a static dashboard. (Chunks here are shown but not run —
the app needs `shiny` and, for the table, `DT`.)

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

- a **predator** selector;
- a **mode** switch (count / occurrence / weight);
- an optional **facet** covariate to compare levels side by side;
- a **rank** selector for the importance table.

The server subsets the records for the chosen predator, builds the tree
reactively with
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
renders the sunburst with the shared palette, and shows the within-rank
importance table for the chosen rank.

## When to use the app vs. the dashboard

Use the **app** for live exploration on your own machine. Use
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
/
[`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
to produce a **self-contained HTML** file you can archive, email, or
serve — no R session required by the reader.
