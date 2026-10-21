# DietView

> Interactive, hierarchical visualization of predator stomach-content
> data

Stomach contents are identified to uneven depth: one prey is named to
species, the next only to “Teleostei”, and some material cannot be
placed at all. DietView keeps all of it. From a long table with one row
per prey record, it attaches a taxonomic lineage (from WoRMS, or from a
lineage table you supply), keeps every record that stopped at a coarse
rank as an explicit *unidentified* category below that rank, and shows
the whole diet at every rank in one sunburst, by prey records or by
weight. It also reports the classical frequency of occurrence, how
identification depth changes with digestion, and can write the result to
a single HTML file that opens in any browser. See the [documentation
site](https://sosthenea.github.io/DietView/).

## Table of contents

- [Overview](#overview)
- [Documentation](#documentation)
- [Installation](#installation)
- [Basic use](#basic-use)
- [The explicit-NA philosophy](#the-explicit-na-philosophy)
- [Function reference](#function-reference)
- [Input format](#input-format)
- [Getting help](#getting-help)
- [Citation](#citation)
- [Related work](#related-work)

## Overview

DietView is built around a single input contract (*one row per prey
record in a stomach*) and one reusable specification object. From there
it offers:

- **taxonomy on demand**: resolve prey against WoRMS by AphiaID
  (preferred) or name, following unaccepted names to their valid
  AphiaID, with exact matching first, then WoRMS TAXAMATCH for
  misspellings, and a provenance log to review; or join a lineage table
  for a fully offline, reproducible run;
- **within-rank importance** in two currencies (prey records and
  weight), where every taxonomic rank sums to 100 % and unidentified
  prey is an explicit **NA** category rather than a dropped row;
- **covariate stratification** by any user-declared columns (period,
  year, size class, length bins, region, …), plus helpers to derive
  periods and length bins;
- a **digestion identification-bias diagnostic** that shows how the
  finest resolved rank shifts toward coarse ranks as digestion advances;
- **interactive sunbursts** (plotly), with one color per taxon kept the
  same in every panel, so strata can be compared at a glance;
- three **outputs**: a [Shiny](https://shiny.posit.co/) explorer, a
  self-contained HTML dashboard (searchable, sortable predator cards,
  with optional ID photos from iNaturalist or Wikimedia Commons, each
  credited with its author and license), or plain plotly figures;
- **exploration & reproducible aggregation**: sample summaries,
  prey-accumulation curves for sampling sufficiency, classical per-rank
  frequency of occurrence, threshold-based aggregation that collapses
  rare prey upward to a reproducible resolution (pooled, cross-predator,
  and per-predator), and a sampling-unit by prey-category matrix export
  for multivariate analysis.

The package ships real, public data to learn on: `ices_diet` (9,639 prey
records from 4,231 stomachs of 22 fish species, North Sea,
Skagerrak-Kattegat and Baltic Sea, 2020-2024), `ices_stomachs` (every
sampled stomach, empty ones included) and `ices_lineage` (their frozen
WoRMS classification). Source: ICES Stomach Content Database, ICES,
Copenhagen; extract distributed with the R package stomachr (Lindmark
2026). See
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md).

## Documentation

Everything lives on the **[documentation
site](https://sosthenea.github.io/DietView/)**. The articles are
rendered end-to-end on the bundled ICES stomach data (the known-diet
article uses a simulated survey instead), so the tables and sunbursts
you see there are real output.

**Start here**

|  | Article | What it covers |
|----|----|----|
| 1 | [Getting started](https://sosthenea.github.io/DietView/articles/getting-started.html) | the whole pipeline, end to end, offline |
| 2 | [Data model & input contract](https://sosthenea.github.io/DietView/articles/data-model.html) | one row per prey record; mapping your columns |

**Case study**

|  | Article | What it covers |
|----|----|----|
| 3 | [Case study: a complete analysis of public ICES stomach data](https://sosthenea.github.io/DietView/articles/case-study-ices.html) | a full worked analysis of the bundled ICES data, from the raw records to figures and a dashboard |

**Core concepts**

|  | Article | What it covers |
|----|----|----|
| 4 | [Within-rank importance & explicit NA](https://sosthenea.github.io/DietView/articles/within-rank-na.html) | why each rank sums to 100 %, NA included |
| 5 | [Covariate stratification](https://sosthenea.github.io/DietView/articles/covariates.html) | periods, size bins, and crossing two covariates |
| 6 | [Digestion identification bias](https://sosthenea.github.io/DietView/articles/digestion.html) | how identification degrades with digestion |
| 7 | [WoRMS taxonomy](https://sosthenea.github.io/DietView/articles/taxonomy-worms.html) | matching, provenance, and reviewing fuzzy hits |
| 8 | [Exploring & aggregating diet data](https://sosthenea.github.io/DietView/articles/exploration.html) | sample summary, prey-accumulation, true %FO, threshold aggregation, set x category matrix |
| 9 | [A known diet](https://sosthenea.github.io/DietView/articles/known-diet.html) | a simulated survey: what keeping or dropping unidentified prey does |

**Outputs & extension**

|  | Article | What it covers |
|----|----|----|
| 10 | [Self-contained dashboard](https://sosthenea.github.io/DietView/articles/dashboard.html) | bands, strata, crossed rows, one file to ship |
| 11 | [Species identification cards](https://sosthenea.github.io/DietView/articles/species-cards.html) | photos from iNaturalist, licenses and credits, offline mode |
| 12 | [Interactive Shiny explorer](https://sosthenea.github.io/DietView/articles/shiny-app.html) | pooled or per-predator, faceted and crossed |
| 13 | [Adapting DietView to your survey](https://sosthenea.github.io/DietView/articles/extending.html) | custom ranks, colors, offline taxonomy |

> ### 📘 Technical reference: the package companion
>
> The full narrative of **what DietView contains and why**: design
> principles, architecture, data structures, and every function with its
> internal logic. Distinct from the journal article (which argues *why*
> the package matters) and from the [function
> reference](https://sosthenea.github.io/DietView/reference/index.html)
> (the API).
>
> **[Read it
> online](https://sosthenea.github.io/DietView/articles/technical-reference.html)**

## Installation

DietView is distributed through [R-universe](https://r-universe.dev):

``` r

install.packages("DietView",
  repos = c("https://sosthenea.r-universe.dev", "https://cloud.r-project.org"))
```

Or install the development version from GitHub:

``` r

# install.packages("pak")
pak::pak("SostheneA/DietView")
```

Optional features need a few more packages: `worrms` (WoRMS taxonomy),
`shiny` + `DT` (interactive app), `rmarkdown` (self-contained HTML).

``` r

install.packages(c("worrms", "shiny", "DT", "rmarkdown"))
```

## Basic use

A minimal, fully offline workflow on the bundled ICES stomach data (a
long table of prey records plus a frozen lineage lookup, so no internet
is required):

``` r

library(DietView)

# 1. base long table: one row per prey record, NO taxonomy columns
#    (drop non-food items and nematodes, which are mostly parasites, not prey)
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]

# 2. declare column roles once (nothing is hard-coded)
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

# 3. attach taxonomy -- offline via a lineage table ...
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)

#    ... or live from WoRMS (needs 'worrms' + internet; results are cached):
# prep <- dv_prepare(dat, spec, taxonomy = "worms")

# 4. metrics: within-rank importance (NA included; each rank sums to 100 %)
tree <- dv_tree(prep)
dv_rank_table(tree, "Class")

# 5. figures + digestion diagnostic, here for Atlantic cod
cod <- dv_prepare(dat[dat$predator_common == "Atlantic cod", ], spec,
                  taxonomy = "table", lineage = ices_lineage, verbose = FALSE)
dv_sunburst(dv_tree(cod), mode = "occurrence", title = "Atlantic cod")
dv_digestion_diagnostic(cod, by = "region")

# 6. explore, check sampling sufficiency, aggregate, and export
dv_summary(prep)                                  # stomachs, records, taxa per predator
dv_prey_accumulation(cod, permutations = 50)      # cumulative prey curve
dv_fo_table(cod, rank = "class")                  # classical per-rank %FO

agg  <- dv_aggregate_threshold(cod, threshold = 10)    # prey in < 10 stomachs move up a rank
m    <- dv_matrix(agg, currency = "occurrence")        # set x category matrix (-> vegan)

# 7. write a standalone HTML dashboard (one file, opens in any browser)
dv_deploy(cod, file = "cod_dashboard.html", dir = tempdir(),
          strata = c("region", "quarter"),
          length_col = "length_cm")

# or explore interactively
run_dietview(prep)
```

See [Getting started with
DietView](https://sosthenea.github.io/DietView/articles/getting-started.html)
for the rendered walk-through.

## The explicit-NA philosophy

Where identification stops, or WoRMS has no finer rank, DietView keeps
the deeper rank columns as `NA` and shows them as an explicit **“NA”**
category (white in the sunburst). Two consequences follow:

- within-rank percentages still sum to **100 %**, so nothing is quietly
  rebased onto the identified fraction only;
- identification gaps stay **visible** instead of being hidden inside a
  functional grouping.

The digestion diagnostic makes this concrete. On real surveys, records
identified to species become rarer as digestion advances, and more of
them stop at a coarse rank or stay unresolved; the diagnostic shows by
how much, instead of hiding it.

## Function reference

| Step | Functions |
|----|----|
| declare & validate | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.html), [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.html) |
| attach taxonomy | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.html), [`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.html), [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.html) |
| covariates | [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.html), [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.html) |
| metrics | [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.html), [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.html), [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.html) |
| figures | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.html), [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.html), [`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.html) |
| digestion bias | [`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.html) |
| species cards | [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.html) |
| dashboards & app | [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.html), [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.html), [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.html) |
| explore & aggregate | [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.html), [`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.html), [`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.html), [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.html), [`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.html), [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.html) |

## Input format

One row = **one prey record in one stomach**. Column names are free; you
map them to DietView roles once via
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
The bundled `ices_diet` table is in this format: one row per prey
record, with the stomach-level variables (predator, length, haul,
region, year, …) repeated on each row, and its lineage lookup is
`ices_lineage` (ICES Stomach Content Database, ICES, Copenhagen; extract
distributed with the R package stomachr, Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)).
The data dictionary (`inst/extdata/dietview_data_dictionary.md`) also
documents the small 24-record example `dietview_example.csv` (base
table) and `dietview_example_lineage.csv` (lineage lookup), kept for
tests and quick checks of the mechanics.

## Getting help

For bugs or feature requests, please use the [issue
tracker](https://github.com/SostheneA/DietView/issues).

## Citation

``` r

citation("DietView")
```

## Related work

DietView is a visualization and reporting layer; it does not model diet
composition or fit selectivity. It complements diet-analysis workflows
built on `vegan` (multivariate community statistics), to which
[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
is the direct bridge, the WoRMS toolchain (`worrms`), and interactive
graphics via `plotly` and `htmlwidgets`. The sunburst and dashboard
design follow the southern Gulf of St. Lawrence (sGSL) diet dashboard it
generalizes.
