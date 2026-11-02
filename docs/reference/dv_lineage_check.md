# Check a lineage for spelling variants and inconsistent placements

An offline check of the lineage attached to the prey, run before any
figure is made. It flags two problems that split one taxon into several
nodes of the tree, and so inflate the number of taxa and of threshold
categories:

- **near_duplicate**: two different labels at the same rank under the
  same parent whose spellings differ by at most `max_dist` edits (and by
  at most 10% of the length of the longer label). These are often an
  unaccepted spelling kept alongside the accepted name, e.g. a lineage
  frozen from an identifier that was not followed to its accepted
  record.

- **multi_parent**: one label placed under more than one parent at the
  same rank, which gives that taxon two separate wedges.

It also flags **genus_mismatch**: a binomial at the finest rank whose
first word differs from the genus.

## Usage

``` r
dv_lineage_check(x, ranks = NULL, max_dist = 2L)
```

## Arguments

- x:

  A lineage data.frame (one row per prey key) or a `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).
  With a `dietview_prep`, the number of records carrying each flagged
  label is reported.

- ranks:

  Rank columns, coarse to fine. Defaults to the ranks of the
  `dietview_prep`, or to kingdom..species for a lineage table.

- max_dist:

  Largest edit distance (see
  [`utils::adist()`](https://rdrr.io/r/utils/adist.html)) at which two
  labels are flagged as near duplicates.

## Value

A data.frame with one row per flag: `check`, `rank`, `parent`, `label`,
`variant` (the other spelling or the other parent), `distance` and
`n_records` (`NA` for a lineage table). Zero rows when nothing is
flagged.

## Details

The check proposes; it does not repair. Correct the lineage table (or
the matching against WoRMS with
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)`(taxonomy = "worms")`,
which follows unaccepted AphiaIDs to their accepted record) and archive
the corrected table with the results.

## Examples

``` r
chk <- dv_lineage_check(ices_lineage)
chk[, c("check", "rank", "label", "variant")]
#>            check    rank                    label                  variant
#> 1 near_duplicate   genus                Aphrodita                Aphrodite
#> 2 near_duplicate species      Trisopterus esmarki     Trisopterus esmarkii
#> 3 near_duplicate species Lumpenus lampetraeformis Lumpenus lampretaeformis
```
