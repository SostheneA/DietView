# Frozen WoRMS lineage for the ICES example data

The taxonomic lineage (kingdom to species) of every AphiaID in
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md),
as resolved in WoRMS. Pass it to
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
with `taxonomy = "table"`: its key column, `prey_aphia_id`, has the same
name as the prey key of
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md).
A taxon that is itself above species (e.g. "Crustacea", a subphylum) has
`NA` at the finer ranks, which DietView shows as the unidentified share
of that branch. WoRMS gives no order to some polychaetes and lancelets
and no class to Priapulida, so a few records identified to family or
species also reach an `NA` node at those ranks.

## Usage

``` r
ices_lineage
```

## Format

A data frame with 461 rows and 10 columns: `prey_aphia_id`,
`scientific_name`, `worms_rank` (the WoRMS rank of the name), then the
seven ranks `kingdom`, `phylum`, `class`, `order`, `family`, `genus`,
`species`.

## Source

World Register of Marine Species (WoRMS,
<https://www.marinespecies.org>), as compiled in the R package stomachr
(Lindmark 2026); kingdom and species columns derived from the WoRMS
phylum and the name's rank.

## Examples

``` r
ices_lineage[ices_lineage$scientific_name %in% c("Crustacea", "Crangon crangon"), ]
#>    prey_aphia_id scientific_name worms_rank  kingdom     phylum        class
#> 48        107552 Crangon crangon    Species Animalia Arthropoda Malacostraca
#> 77          1066       Crustacea  Subphylum Animalia Arthropoda         <NA>
#>       order      family   genus         species
#> 48 Decapoda Crangonidae Crangon Crangon crangon
#> 77     <NA>        <NA>    <NA>            <NA>
```
