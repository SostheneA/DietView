# Building a self-contained diet dashboard

[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
reproduces the southern Gulf of St. Lawrence (sGSL) diet dashboard from
any prepared dataset: a searchable, sortable landing grid of predator
cards, plus one tab per predator. Each predator tab shows the diet in up
to three **bands** — distinct diet items, occurrence share within rank,
and weight share within rank — and each band repeats the same structure:
an aggregated sunburst, one row of sunbursts per declared covariate, and
optionally crossed rows.

``` r

library(DietView)

dat <- read.csv(
  system.file("extdata", "dietview_example.csv", package = "DietView"),
  na.strings = c("NA", "")
)
lin <- read.csv(
  system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
  na.strings = c("NA", "")
)
spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",
  prey_name      = "verified_name",
  weight         = "prey_weight",
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin)
```

## The simplest dashboard

``` r

dv_build_html(prep, output = "diet_dashboard.html")
```

## Stratifying each band by covariates

`strata` picks which covariates get their own row of sunbursts in every
band; `cross` adds crossed rows (for each level of `outer`, a row of
`inner` levels).

``` r

dv_build_html(
  prep,
  output = "diet_dashboard.html",
  strata = c("period", "size_class", "size_bin"),
  cross  = list(c("size_bin", "period")),   # length bins x period
  bands  = c("count", "occurrence", "weight"),
  length_col = "somatic_length_cm"
)
```

## Identification cards

Each predator card can show an identification photo and a short
description. DietView resolves the photo in priority order — a local
file, a Wikimedia Commons file you name, or a Wikipedia thumbnail
fetched by Latin name — and embeds it as a base64 data URI so the
dashboard stays a single self-contained file. Turn the network lookups
off with `use_wiki = FALSE`, or supply your own assets:

``` r

info <- list(
  "Atlantic cod" = list(
    desc  = "Demersal gadid; opportunistic predator of fish and invertebrates.",
    photo = "images/atlantic_cod.jpg"
  )
)
dv_build_html(prep, output = "diet_dashboard.html",
              species_info = info, image_dir = "images", use_wiki = TRUE)
```

## Deploying to a folder

[`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
is a thin wrapper that writes the self-contained dashboard into a
destination directory (e.g. one served by your web platform) and returns
its path.

``` r

dv_deploy(prep, file = "dietview_dashboard.html", dir = "outputs",
          strata = c("period", "size_class", "size_bin"),
          cross  = list(c("size_bin", "period")),
          length_col = "somatic_length_cm")
```
