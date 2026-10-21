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

  Name of a count column (or `NULL`: each record counts once).

- rank_labels:

  Optional display labels for the ranks.

## Value

A `dietview_tree` data.frame:
`id, label, parent, rank, value_item, value_occ, value_w, pct_occ, pct_w`,
with the attribute `currency` (`"records"`, or `"numbers"` when
`count_col` is given).

## Details

Three quantities are carried through the tree:

- `value_item`: number of distinct prey items (terminal lineages) under
  the node.

- `value_occ`: number of prey records assigned to the node, or, when
  `count_col` is given, the summed number of individuals (records with
  an empty count then contribute 0).

- `value_w`: summed weight.

Aggregation is done at the finest rank and rolled up, so a parent's
value equals the sum of its children. Every record reaches every rank,
under a taxon or under the unidentified (`"NA"`) node, so the
denominator is the same at every rank: all records (or individuals) and
all weight. The columns `pct_occ` (share of prey records, or numerical
share %N with `count_col`) and `pct_w` (weight share %W) therefore sum
to 100% within each rank, the unidentified node included. Within each
parent, unidentified nodes are placed last.

To build the tree from a prepared dataset with the columns of its spec,
use
[`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md).

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
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
head(tree)
#>                    id      label   parent    rank value_item value_occ
#> 1            Animalia   Animalia          Kingdom        237      6975
#> 2           Chromista  Chromista          Kingdom          1         1
#> 3             Plantae    Plantae          Kingdom          1         1
#> 4                  NA         NA          Kingdom          1      1553
#> 5   Animalia|Annelida   Annelida Animalia  Phylum         33       785
#> 6 Animalia|Arthropoda Arthropoda Animalia  Phylum         97      2779
#>      value_w     pct_occ        pct_w
#> 1 20782.9124 81.77022274 9.490663e+01
#> 2     0.0000  0.01172333 0.000000e+00
#> 3     0.1480  0.01172333 6.758524e-04
#> 4  1115.2120 18.20633060 5.092694e+00
#> 5   600.6392  9.20281360 2.742861e+00
#> 6  3450.9192 32.57913247 1.575887e+01
```
