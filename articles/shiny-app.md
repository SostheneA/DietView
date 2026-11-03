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

# the public ICES stomach data that ship with the package (see ?ices_diet)
# drop non-food items and nematodes (mostly parasites, not prey)
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

run_dietview(prep)
```

The data are the ICES Stomach Content Database (ICES, Copenhagen), as
extracted in the R package stomachr (Lindmark 2026): 22 predators from
the North Sea, the Skagerrak-Kattegat and the Baltic Sea. The app opens
on all predators pooled; pick “Atlantic cod” and facet by `region` or
`quarter` for a first comparison. To compare periods or length classes,
add those columns before
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
and declare them, as in the article on covariates:

``` r

dat$period   <- dv_add_period(dat$year, breaks = c(2021.5, 2022, 2024),
                              labels = c("2022", "2023-2024"))
cod <- dat[dat$predator_common == "Atlantic cod", ]
cod$size_bin <- dv_size_bins(cod$length_cm, breaks = c(0, 20, 35, 50, 110))
spec_cod <- dv_spec(predator = "predator_common", stomach = "stomach_id",
                    prey_id = "prey_aphia_id", prey_name = "prey_name",
                    weight = "prey_weight_g", count = "prey_count",
                    digestion = "digestion_label",
                    covariates = c("region", "quarter", "period", "size_bin"))
run_dietview(dv_prepare(cod, spec_cod, taxonomy = "table",
                        lineage = ices_lineage, verbose = FALSE))
```

Records from 2020 and 2021 have no period. By default the app leaves
them out of the panels when you facet by `period` (they stay in the
unfaceted view); `run_dietview(prep, na_strata = "show")` draws them in
a separate “NA” panel instead, as `dv_build_html(na_strata = "show")`
does in the dashboard. That `NA` is a missing stratum, not an
unidentified prey.

`run_dietview(prep, currency = "numbers")` sizes the record view by the
number of individuals (`prey_count`) instead of the number of records.
In the ICES data almost all the unidentified material has no count, so
it nearly disappears from that view.

## What the app offers

- a predator selector, with “(all predators)” to pool every predator;
- a choice of what sizes the wedges: prey records (% of all records),
  weight (% of total weight) or the number of distinct prey items;
- a reporting-resolution selector: the full hierarchy, or rare prey
  merged up their lineage with
  [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
  in one of its three variants (pooled; pooled cross-predator, with a
  minimum number of predators; per predator), with the threshold as a
  number of stomachs;
- a covariate to facet by, which draws one sunburst per level, and a
  second covariate to cross with the first, which draws one sunburst per
  combination;
- a rank selector for the tables.

The tabs show the sunburst, the rank table (shares of records and weight
at the chosen rank, unidentified rows included), the frequency of
occurrence at that rank
([`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md))
and, when the spec declares a digestion column, the digestion diagnostic
([`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)).

Pooled aggregations are computed on all predators before one is
selected, so a category means the same thing in every predator’s view.
Per-predator aggregation counts stomachs within each predator, so its
categories differ between predators.

## Reproducing a view

The **Reproduce** tab shows the R script that rebuilds the current view,
as written by
[`dv_script()`](https://sosthenea.github.io/DietView/reference/dv_script.md),
and offers the script, the prepared data it reads (`dietview_prep.rds`)
and the current tables (CSV) as downloads. The script uses exported
functions only, so it runs without the app, and its header records the
date, the DietView and R versions, the taxonomy source, the reporting
resolution and the column specification. The same script can be written
without the app:

``` r

s <- dv_script(prep, predator = "Atlantic cod", mode = "weight",
               aggregation = list(threshold = 8, scope = "pooled"))
s
```

## The app or the dashboard?

Use the app to explore on your own machine. Use
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
or
[`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
to write a single HTML file that you can archive, email or put on a web
server, and that the reader opens without R.
