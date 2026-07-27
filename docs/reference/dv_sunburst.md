# Render a diet sunburst

Draws the multi-rank sunburst for one set of records (or a prebuilt
tree). Orientation is fixed (`sort = FALSE`, fixed `rotation`) so
reading order and start angle stay consistent across covariate cells,
which makes side-by-side comparison meaningful. The explicit "NA"
category is white.

## Usage

``` r
dv_sunburst(
  x,
  mode = c("count", "occurrence", "weight"),
  ranks = NULL,
  weight_col = NULL,
  count_col = NULL,
  colors = NULL,
  rotation = 90,
  title = "",
  subtitle = ""
)
```

## Arguments

- x:

  A `dietview_tree`, or a data.frame of records (then supply `ranks` and
  `weight_col`/`count_col`).

- mode:

  One of "count", "occurrence", "weight".

- ranks, weight_col, count_col:

  Passed to
  [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
  if `x` is raw.

- colors:

  Optional named colour vector; default from
  [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md).

- rotation:

  Start angle in degrees (default 90 = top).

- title, subtitle:

  Figure titles.

## Value

A plotly sunburst.

## Details

Three modes:

- `count`: sized by distinct diet items.

- `occurrence`: sized by within-rank occurrence share; hover shows raw
  occurrence and % within rank.

- `weight`: sized by within-rank weight share; hover shows raw weight
  and % within rank.

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
                weight = "prey_weight")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
#> No digestion column: digestion diagnostics disabled.
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
p <- dv_sunburst(tree, mode = "occurrence", title = "All predators")
# print(p)  # opens the interactive plotly sunburst
```
