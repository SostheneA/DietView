# Building a self-contained diet dashboard

[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
writes a single HTML file with one page per predator, modeled on the
diet dashboard built for the southern Gulf of St. Lawrence. The landing
page shows one card per predator, with its stomach count and, if you
give a length column, its length range. Each predator page shows the
diet in up to three bands: distinct prey items, prey records (% of all
records) and weight (% of total weight). Every band has the same layout:
one sunburst for all the predator’s records, one row of sunbursts per
covariate you choose, and, if you ask for them, crossed rows.

The chunks below are shown but not run, because they write files. They
use the invented example table that ships with the package.

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

Name the output file yourself. By default the build stays offline, so
the cards have no photo:

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"))
```

## Stratifying each band by covariates

`strata` picks the covariates that get their own row of sunbursts in
every band. `cross` adds crossed rows: `cross = list(c(inner, outer))`
gives one row per level of `outer`, with one sunburst per level of
`inner` in that row.

``` r

dv_build_html(
  prep,
  output = file.path(tempdir(), "diet_dashboard.html"),
  strata = c("period", "size_class", "size_bin"),
  cross  = list(c("size_bin", "period")),   # length bins within periods
  bands  = c("count", "occurrence", "weight"),
  length_col = "somatic_length_cm"
)
```

In `bands`, `"count"` is the distinct prey items band, `"occurrence"`
the prey records band and `"weight"` the weight band. Crossing
multiplies the number of panels: two covariates with four levels each
give sixteen sunbursts per band.

## Identification cards

Each predator card can show a photo and a short description. DietView
looks for a photo in this order: a local file you name in
`species_info`, a local file in `image_dir` named after the predator or
its Latin name, then, if you ask for it, an openly licensed photo from
iNaturalist (`photo_source = "inaturalist"`) or from Wikipedia and
Wikimedia Commons (`photo_source = "wikipedia"`). The photo is embedded
in the HTML file, so the file stays complete on its own. To control what
is shown, supply your own description and photo:

``` r

info <- list(
  "Atlantic cod" = list(
    desc  = "Demersal gadid; feeds on fish and invertebrates.",
    photo = "images/atlantic_cod.jpg"
  )
)
dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"),
              species_info = info, image_dir = "images")
```

To fill the cards from iNaturalist, give the predators’ Latin names in
the spec (`predator_latin`) and ask for that source:

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"),
              photo_source = "inaturalist", image_dir = "images")
```

Only photos under CC0, CC BY or CC BY-SA are used unless you widen
`licenses`, and each card shows the photographer and the license, linked
to the photo’s page. Check the credit line on each card before you share
the file. The article on species cards gives the details.

## Deploying to a folder

[`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
calls
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
and writes the file into a folder of your choice, for example one served
by your web platform. It returns the path.

``` r

dv_deploy(prep, file = "dietview_dashboard.html",
          dir = file.path(tempdir(), "outputs"),
          strata = c("period", "size_class", "size_bin"),
          cross  = list(c("size_bin", "period")),
          length_col = "somatic_length_cm")
```

The dashboard is a snapshot. It holds the data as they were when you
built it, opens in any browser and needs neither R nor an internet
connection.
