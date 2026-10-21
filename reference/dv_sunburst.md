# Render a diet sunburst

Draws the multi-rank sunburst for one set of records (or a prebuilt
tree). Orientation is fixed (`sort = FALSE`, fixed `rotation`), so the
start angle and the reading order stay the same across covariate cells.
Angular positions are not fixed: a taxon absent from one cell shifts
every wedge after it, so compare cells by color, not by angle. Records
not identified at a rank form a white wedge with a thin gray outline,
shown as "Not identified at this rank" in the hover text.

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

  Optional named color vector, keyed by node `id` (as from
  [`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md))
  or by taxon label (as from
  [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md));
  ids are looked up first. Default from
  [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md).

- rotation:

  Start angle in degrees (default 90 = top).

- title, subtitle:

  Figure titles.

## Value

A plotly sunburst.

## Details

Wedges are sized from the raw values of the leaves
(`branchvalues = "remainder"`), and plotly sums them upward, so a parent
always equals the sum of its children. Because every rank has the same
denominator, the angles are the within-rank shares shown in the hover
text.

Three modes:

- `count`: sized by the number of distinct prey items.

- `occurrence`: sized by prey records (or by individuals, if the tree
  was built with a count column); hover shows the number and the share
  of all records at that rank. The value `"occurrence"` is kept for
  backward compatibility.

- `weight`: sized by weight; hover shows the weight and the weight share
  at that rank.

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
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
p <- dv_sunburst(tree, mode = "occurrence", title = "All predators")
# print(p)  # opens the interactive plotly sunburst
```
