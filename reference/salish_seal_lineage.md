# Frozen WoRMS lineage for the Salish Sea harbour seal data

The lineage (kingdom to species) of every `prey_label` of
[salish_seal_dna](https://sosthenea.github.io/DietView/reference/salish_seal_dna.md),
resolved against WoRMS with
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
when the data were built (one misspelling, *Chirolophus decoratus*, was
matched to *Chirolophis decoratus*). For a label listing alternatives
("A OR B"), the ranks the candidate species share are kept and the finer
ranks are `NA`. Pass it to
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
with `taxonomy = "table"`.

## Usage

``` r
salish_seal_lineage
```

## Format

A data frame with 117 rows and 10 columns: `prey_label`, the seven ranks
`kingdom` to `species`, `n_candidates` (species listed in the label) and
`aphia_id` (the WoRMS AphiaID, for single-species labels).

## Source

World Register of Marine Species (WoRMS,
<https://www.marinespecies.org>), retrieved 2026-11-04; see
`data-raw/salish_seal.R`.

## Examples

``` r
salish_seal_lineage[salish_seal_lineage$n_candidates > 1,
                    c("prey_label", "family", "genus")]
#>                                                      prey_label         family
#> 11                   Artedius fenestralis OR Artedius lateralis       Cottidae
#> 13                  Artedius lateralis OR Artedius notospilotus       Cottidae
#> 54              Lepidopsetta bilineata OR Platichthys stellatus Pleuronectidae
#> 102           Scorpaenichthys marmoratus OR Leptocottus armatus           <NA>
#> 104 Sebastes caurinus OR Sebastes maliger OR Sebastes nebulosus     Sebastidae
#> 106                      Sebastes flavidus OR Sebastes melanops     Sebastidae
#>        genus
#> 11  Artedius
#> 13  Artedius
#> 54      <NA>
#> 102     <NA>
#> 104 Sebastes
#> 106 Sebastes
```
