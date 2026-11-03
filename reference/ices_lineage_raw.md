# Uncorrected WoRMS lineage for the ICES example data

The lineage of
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md)
as built from the AphiaIDs as reported, before unaccepted AphiaIDs were
given the lineage of their accepted record. It keeps three species under
two spellings each (*Aphrodita*/*Aphrodite aculeata*, *Trisopterus
esmarkii*/*esmarki*, *Lumpenus lampretaeformis*/*lampetraeformis*),
which split one taxon into two nodes. It is shipped to demonstrate
[`dv_lineage_check()`](https://sosthenea.github.io/DietView/reference/dv_lineage_check.md);
use
[ices_lineage](https://sosthenea.github.io/DietView/reference/ices_lineage.md)
for analyses.

## Usage

``` r
ices_lineage_raw
```

## Format

A data frame with the same 461 rows and 10 columns as
[ices_lineage](https://sosthenea.github.io/DietView/reference/ices_lineage.md).

## Source

As
[ices_lineage](https://sosthenea.github.io/DietView/reference/ices_lineage.md).

## Examples

``` r
dv_lineage_check(ices_lineage_raw)[, c("check", "rank", "label", "variant")]
#>            check    rank                    label                  variant
#> 1 near_duplicate   genus                Aphrodita                Aphrodite
#> 2 near_duplicate species      Trisopterus esmarki     Trisopterus esmarkii
#> 3 near_duplicate species Lumpenus lampetraeformis Lumpenus lampretaeformis
```
