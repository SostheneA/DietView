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
# the standard set-up: public ICES data, non-food items and nematodes dropped
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
# Atlantic cod only, for speed
cod <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)

# a dashboard for cod, stratified by quarter, written to tempdir();
# self_contained = FALSE keeps this quick and needs no pandoc; the default
# (TRUE) embeds everything in one file
out <- dv_build_html(prep_cod, output = file.path(tempdir(), "cod_dashboard.html"),
                     strata = "quarter", bands = "count",
                     self_contained = FALSE)
file.exists(out)
#> [1] TRUE
```
