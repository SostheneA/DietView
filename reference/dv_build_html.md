# Build a self-contained HTML diet dashboard

Reproduces the sGSL-style dashboard from any prepared dataset: a
searchable, sortable landing grid of predator cards (stomach counts,
length range, ID photo, description) plus one tab per predator. Each tab
shows the diet in up to three bands (occurrence items, occurrence %,
weight %); each band repeats the same structure: an aggregated sunburst,
one row of sunbursts per declared covariate, and optionally crossed rows
(e.g. length bins split by period).

## Usage

``` r
dv_build_html(
  prep,
  output = "dietview.html",
  strata = prep$spec$covariates,
  cross = list(),
  bands = c("count", "occurrence", "weight"),
  length_col = NULL,
  species_info = list(),
  image_dir = "images",
  use_wiki = TRUE,
  title = "DietView",
  self_contained = TRUE
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- output:

  Output HTML path.

- strata:

  Covariates to stratify each band by (default: all declared).

- cross:

  List of `c(inner, outer)` covariate pairs to also show crossed (for
  each level of `outer`, a row of `inner` levels). E.g.
  `list(c("size_bin", "period"))`.

- bands:

  Which bands to draw and in which order.

- length_col:

  Optional numeric length column, to show length ranges on cards.

- species_info:

  Optional named list of `list(desc=, photo=)` per predator.

- image_dir, use_wiki:

  Passed to
  [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md).

- title:

  Dashboard title.

- self_contained:

  If TRUE render a single embedded file (needs rmarkdown).

## Value

The output path, invisibly.

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
