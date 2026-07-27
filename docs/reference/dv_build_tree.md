# Build the multi-rank tree with within-rank importance

Aggregates a set of records into a node table spanning all ranks.

## Usage

``` r
dv_build_tree(
  df,
  ranks,
  weight_col = NULL,
  count_col = NULL,
  rank_labels = NULL
)
```

## Arguments

- df:

  A data.frame of records with the rank columns present.

- ranks:

  Ranks, coarse to fine.

- weight_col:

  Name of the weight column (or `NULL` -\> zero weight).

- count_col:

  Name of a count column (or `NULL` -\> one occurrence per record).

- rank_labels:

  Optional display labels for the ranks.

## Value

A `dietview_tree` data.frame:
`id, label, parent, rank, value_item, value_occ, value_w, pct_occ, pct_w`.

## Details

Three quantities are carried through the tree:

- `value_item`: number of distinct terminal diet items (taxonomic
  leaves).

- `value_occ`: occurrence count, i.e. one appearance per record (or a
  summed count column).

- `value_w`: summed weight.

Aggregation is done at the finest rank and rolled up, so a parent's
value equals the sum of its children (required for a coherent sunburst
with `branchvalues = "total"`). The importance columns `pct_occ` /
`pct_w` are the share of each node **within its own rank** (the explicit
"NA" node included), so every rank sums to 100%.

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
head(tree)
#>                    id      label   parent    rank value_occ value_w   pct_occ
#> 1            Animalia   Animalia          Kingdom        22 75.5968 91.666667
#> 2                  NA         NA          Kingdom         2  1.6000  8.333333
#> 3   Animalia|Annelida   Annelida Animalia  Phylum         2  0.7030  8.333333
#> 4 Animalia|Arthropoda Arthropoda Animalia  Phylum        15 39.7648 62.500000
#> 5   Animalia|Chordata   Chordata Animalia  Phylum         3 35.1000 12.500000
#> 6   Animalia|Mollusca   Mollusca Animalia  Phylum         2  0.0290  8.333333
#>         pct_w
#> 1 97.92737523
#> 2  2.07262477
#> 3  0.91065951
#> 4 51.51094346
#> 5 45.46820594
#> 6  0.03756632
```
