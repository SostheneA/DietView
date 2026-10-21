# Build a self-contained HTML diet dashboard

Reproduces the sGSL-style dashboard from any prepared dataset: a
searchable, sortable landing grid of predator cards (stomach counts,
length range, ID photo, description) plus one tab per predator. Each tab
shows the diet in up to three bands of sunbursts (distinct prey items,
prey records as % of all records, weight as % of total weight); each
band repeats the same structure: an aggregated sunburst, one row of
sunbursts per declared covariate, and optionally crossed rows (e.g.
length bins split by period). Covariate levels that are `NA` are omitted
from the rows.

## Usage

``` r
dv_build_html(
  prep,
  output,
  strata = prep$spec$covariates,
  cross = list(),
  bands = c("count", "occurrence", "weight"),
  currency = c("records", "numbers"),
  length_col = NULL,
  species_info = list(),
  image_dir = file.path(tempdir(), "dietview-images"),
  photo_source = "none",
  licenses = c("cc0", "cc-by", "cc-by-sa"),
  use_wiki = NULL,
  title = "DietView",
  self_contained = TRUE
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- output:

  Output HTML path (required).

- strata:

  Covariates to stratify each band by (default: all declared).

- cross:

  List of `c(inner, outer)` covariate pairs to also show crossed (for
  each level of `outer`, a row of `inner` levels). E.g.
  `list(c("size_bin", "period"))`.

- bands:

  Which bands to draw and in which order: `"count"` (distinct prey
  items), `"occurrence"` (prey records, or individuals with
  `currency = "numbers"`) and `"weight"`.

- currency:

  `"records"` (default: each record counts once) or `"numbers"` (each
  record counts its `count` column; needs `count` in the spec). See
  [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md).

- length_col:

  Optional numeric length column, to show length ranges on cards.

- species_info:

  Optional named list, one element per predator, of
  `list(desc =, photo =, credit =, author =, license =, url =)`.

- image_dir, photo_source, licenses:

  Passed to
  [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md).
  Defaults: a folder in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), no network
  access, and only openly licensed iNaturalist photos (CC0, CC BY, CC
  BY-SA).

- use_wiki:

  Deprecated; use `photo_source`.

- title:

  Dashboard title.

- self_contained:

  If TRUE render a single embedded file (needs rmarkdown).

## Value

The output path, invisibly.

## Details

By default the record band counts prey records, even when the spec
declares a `count` column; set `currency = "numbers"` to count
individuals (%N) instead. The default call touches neither the network
nor the working directory: photos are fetched only with
`photo_source = "inaturalist"` or `"wikipedia"`, and downloads go to a
folder in [`tempdir()`](https://rdrr.io/r/base/tempfile.html) unless
`image_dir` says otherwise. Each card shows the photo's author and
license, linked to the photo's page; see
[`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md).

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
                weight = "prey_weight", digestion = "digestion_level_id")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
if (FALSE) { # \dontrun{
# writes a self-contained HTML dashboard
dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"),
              strata = c("period", "size_class"))
} # }
```
