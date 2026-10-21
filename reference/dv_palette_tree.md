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
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
tree <- dv_tree(prep)
cols <- dv_palette_tree(tree)
head(cols)
#>            Animalia           Chromista             Plantae                  NA 
#>           "#BDBDBD"           "#BDBDBD"           "#BDBDBD"           "#FFFFFF" 
#>   Animalia|Annelida Animalia|Arthropoda 
#>           "#1F77B4"           "#FF7F0E" 
p <- dv_sunburst(tree, mode = "occurrence", colors = cols)
```
