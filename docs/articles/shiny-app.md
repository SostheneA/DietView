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

Records from 2020 and 2021 have no period; the app shows them in a
separate “NA” panel when you facet by `period`. That `NA` is a missing
stratum, not an unidentified prey.

`run_dietview(prep, currency = "numbers")` sizes the record view by the
number of individuals (`prey_count`) instead of the number of records.
In the ICES data almost all the unidentified material has no count, so
it nearly disappears from that view.

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
