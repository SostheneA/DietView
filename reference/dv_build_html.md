# Build a self-contained HTML diet dashboard

Builds a dashboard from any prepared dataset: a searchable, sortable
landing grid of predator cards (stomach counts, length range, ID photo,
description) plus one tab per predator. Each tab shows the diet in bands
of sunbursts (by default prey records as % of all records and weight as
% of total weight; distinct prey items on request); each band repeats
the same structure: an aggregated sunburst, one row of sunbursts per
declared covariate, and optionally crossed rows (e.g. length bins split
by period). Records whose covariate is `NA` are left out of that
covariate's rows by default (`na_strata = "drop"`); `na_strata = "show"`
gives them an "NA" panel, as in
[`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md).

## Usage

``` r
dv_build_html(
  prep,
  output,
  strata = prep$spec$covariates,
  cross = list(),
  bands = c("occurrence", "weight"),
  currency = c("records", "numbers"),
  length_col = NULL,
  species_info = list(),
  image_dir = file.path(tempdir(), "dietview-images"),
  photo_source = "none",
  licenses = c("cc0", "cc-by", "cc-by-sa"),
  na_strata = c("drop", "show"),
  min_stomachs = 0,
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

  Which bands to draw and in which order, any of `"occurrence"` (prey
  records, or individuals with `currency = "numbers"`), `"weight"` and
  `"count"` (distinct prey items). Default: occurrence and weight.

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

- na_strata:

  `"drop"` (default) leaves records with a missing covariate value out
  of that covariate's panels; `"show"` draws them in an "NA" panel. The
  aggregated sunburst always holds every record. Same argument in
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md).

- min_stomachs:

  Minimum number of stomachs for a covariate panel to be drawn (default
  0: every panel is drawn). A panel with fewer stomachs keeps its header
  and its "Stomachs (n) = k" line, followed by "Too few stomachs to show
  (minimum: ...)" in place of the sunburst. For example, with
  `min_stomachs = 10` a year with 4 stomachs is not drawn, while the
  year next to it with 522 stomachs is. The aggregated sunburst is
  always drawn. Same argument in
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  and
  [`dv_script()`](https://sosthenea.github.io/DietView/reference/dv_script.md).

- title:

  Dashboard title.

- self_contained:

  If `TRUE` (default), plotly.js is embedded and the dashboard is one
  file. If `FALSE`, plotly.js is written once to a `lib` folder next to
  the file and linked, which keeps the HTML small when several
  dashboards share a folder. Neither needs pandoc.

## Value

The output path, invisibly.

## Details

The file stays small and opens fast: plotly.js is included once, the
data of every sunburst (node ids, labels, parents, values and colors) is
stored once as JSON, and the sunbursts of a tab are drawn the first time
the tab is opened. The file works offline. Colors come from
[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
built on the pooled tree of the whole dataset, so a taxon has the same
color in every panel. The cards can be opened with the mouse or with the
keyboard (Tab, then Enter or Space).

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

# a dashboard for cod, stratified by quarter, written to tempdir()
out <- dv_build_html(prep_cod, output = file.path(tempdir(), "cod_dashboard.html"),
                     strata = "quarter")
file.exists(out)
#> [1] TRUE
```
