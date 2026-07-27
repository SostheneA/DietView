# Within-rank importance and the explicit-NA philosophy

This article explains the two ideas at the heart of DietView: importance
is computed **within each taxonomic rank**, and unidentified prey is
kept as an **explicit “NA” category** rather than dropped. Together they
make the sunburst an honest partition of the diet.

``` r
library(DietView)

dat <- read.csv(system.file("extdata", "dietview_example.csv", package = "DietView"),
                na.strings = c("NA", ""))
lin <- read.csv(system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
                na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name", stomach = "stomach_id",
                prey_id = "aphia_id", prey_name = "verified_name",
                weight = "prey_weight", digestion = "digestion_level_id",
                covariates = c("period", "size_class", "size_bin", "region"))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin)
```

## Building the tree

[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
aggregates records into a node table spanning all ranks, in two
currencies (occurrence and weight).

``` r
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
head(tree[, c("rank", "label", "value_occ", "pct_occ", "value_w", "pct_w")], 8)
#>      rank      label value_occ   pct_occ value_w       pct_w
#> 1 Kingdom   Animalia        22 91.666667 75.5968 97.92737523
#> 2 Kingdom         NA         2  8.333333  1.6000  2.07262477
#> 3  Phylum   Annelida         2  8.333333  0.7030  0.91065951
#> 4  Phylum Arthropoda        15 62.500000 39.7648 51.51094346
#> 5  Phylum   Chordata         3 12.500000 35.1000 45.46820594
#> 6  Phylum   Mollusca         2  8.333333  0.0290  0.03756632
#> 7  Phylum         NA         2  8.333333  1.6000  2.07262477
#> 8   Class Polychaeta         2  8.333333  0.7030  0.91065951
```

## Each rank is its own 100 %

Importance is the share of a node **within its own rank**, so every rank
sums to 100 % independently — the explicit `NA` node included.

``` r
sapply(unique(tree$rank), function(r) round(sum(tree$pct_occ[tree$rank == r]), 3))
#> Kingdom  Phylum   Class   Order  Family   Genus Species 
#>     100     100     100     100     100     100     100
```

[`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
gives the sorted importance table for one rank:

``` r
dv_rank_table(tree, "Class")
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca          7        11 45.833333 39.7600 51.504725584
#> 9      Copepoda          2         4 16.666667  0.0048  0.006217874
#> 11    Teleostei          3         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta          1         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia          1         2  8.333333  0.0290  0.037566324
#> 13           NA          1         2  8.333333  1.6000  2.072624772
```

## NA is information, not an error

Where identification stops, DietView keeps an explicit `NA` node (white
in the sunburst) instead of rebasing percentages onto the identified
fraction. The `NA` row is present at every rank where some prey are
unresolved:

``` r
subset(dv_rank_table(tree, "Order"), label == "NA")
#>    label value_item value_occ  pct_occ value_w        pct_w
#> 14    NA          1         2 8.333333  0.7030  0.910659509
#> 16    NA          1         2 8.333333  0.0018  0.002331703
#> 23    NA          1         2 8.333333  0.0290  0.037566324
#> 24    NA          1         2 8.333333  1.6000  2.072624772
#> 20    NA          1         1 4.166667  8.0000 10.363123860
```

## The sunburst

Reading coarse (centre) to fine (edge), with `NA` shown in white:

``` r
dv_sunburst(tree, mode = "occurrence", title = "All predators",
            subtitle = "occurrence share within each rank")
```

Occurrence and weight routinely disagree — showing both is part of an
honest diet description:

``` r
dv_sunburst(tree, mode = "weight", title = "All predators",
            subtitle = "weight share within each rank")
```

## A stable colour dictionary

[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
assigns each taxon a stable colour so it keeps the same colour across
ranks and covariate cells; `NA` is always white.

``` r
pal <- dv_palette(tree$label)
head(pal)
#>   Animalia   Annelida Arthropoda   Chordata   Mollusca Polychaeta 
#>  "#1f77b4"  "#aec7e8"  "#ff7f0e"  "#ffbb78"  "#2ca02c"  "#98df8a"
pal[["NA"]]
#> [1] "#FFFFFF"
```
