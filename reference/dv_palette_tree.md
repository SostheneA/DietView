# Colors that follow the taxonomic hierarchy

One hue per node at `base_rank` (for example one per phylum), lighter
tints of that hue for its descendants, unidentified nodes white. Colors
are keyed by node `id`, so a taxon keeps its color in every panel built
from trees of the same ranks; pass the result as `colors` to
[`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md).
Nodes above `base_rank`, and nodes below an unidentified `base_rank`
node, are gray.

## Usage

``` r
dv_palette_tree(tree, base_rank = 2L, palette = .DV_D3[c(TRUE, FALSE)])
```

## Arguments

- tree:

  A `dietview_tree` from
  [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
  or
  [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md).
  To keep colors stable across strata, build the palette from the pooled
  tree.

- base_rank:

  Position (1 = coarsest) of the rank that gets one hue per node.
  Default 2 (phylum with the default ranks).

- palette:

  Base hues to cycle through. Defaults to the ten darker colors of the
  d3 category-20 set.

## Value

A named character vector mapping node id -\> hex color.

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id", prey_id = "aphia_id",
                prey_name = "verified_name", weight = "prey_weight")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
tree <- dv_tree(prep)
cols <- dv_palette_tree(tree)
head(cols)
#>            Animalia                  NA   Animalia|Annelida Animalia|Arthropoda 
#>           "#BDBDBD"           "#FFFFFF"           "#1F77B4"           "#FF7F0E" 
#>   Animalia|Chordata   Animalia|Mollusca 
#>           "#2CA02C"           "#D62728" 
p <- dv_sunburst(tree, mode = "occurrence", colors = cols)
```
