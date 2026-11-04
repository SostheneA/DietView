# DNA metabarcoding diet of Salish Sea harbour seals

Prey composition of 4,625 harbour seal (*Phoca vitulina*) scats
collected at 52 haul-out sites of the Salish Sea (British Columbia and
Washington State) from 2012 to 2018, identified by DNA metabarcoding
(16S, plus COI for salmonids and some fishes). One row per prey taxon in
a scat. It is the public dataset of Thomas et al. (2022), shipped to
show DietView on non-stomach, read-based diet data; see the article
"Beyond stomachs".

## Usage

``` r
salish_seal_dna
```

## Format

A data frame with 11,641 rows and 14 columns:

- sample_id:

  Scat identifier (unique).

- predator:

  "Harbour seal".

- site, lat, lon:

  Haul-out site and its position (decimal degrees).

- year, month:

  Collection date.

- season:

  Factor derived from `month` (winter = Dec-Feb, ...).

- lab:

  Laboratory that processed the scat (DFO, UBC or WDFW).

- prey_label:

  Prey taxon as assigned, or alternatives joined by "OR".

- common_name:

  Prey common name, as given by the authors.

- reads_16S, reads_COI:

  Sequence reads of the prey for each marker.

- diet_fraction:

  Proportion of the scat's prey DNA (0-1).

## Source

Thomas, A. C., Deagle, B., Nordstrom, C., Majewski, S., Nelson, B. W.,
Acevedo-Gutiérrez, A., Jeffries, S., Moore, J., Louden, A., Allegue, H.,
Pearson, S., Schmidt, M., & Trites, A. W. (2022). Data on the diets of
Salish Sea harbour seals from DNA metabarcoding. *Scientific Data*, 9,
68.
[doi:10.1038/s41597-022-01152-5](https://doi.org/10.1038/s41597-022-01152-5)
. Data:
[doi:10.6084/m9.figshare.12043173](https://doi.org/10.6084/m9.figshare.12043173)
, released under CC0 1.0. Labels were cleaned (underscores to spaces);
nothing else was changed.

## Details

`diet_fraction` is the authors' proportion of the scat's prey DNA
assigned to that prey (relative read abundance, combining both markers);
it sums to 1 within each scat. Use it as the weight with
`weight_type = "rra"`. Some sequences could not be split between closely
related species and are reported as alternatives
(`"Sebastes flavidus OR Sebastes melanops"`):
[salish_seal_lineage](https://sosthenea.github.io/DietView/reference/salish_seal_lineage.md)
places them at the finest rank the candidates share, so they show as
unidentified below that rank, as a digested stomach item would.

## Examples

``` r
spec <- dv_spec(predator = "predator", stomach = "sample_id",
                prey_name = "prey_label", weight = "diet_fraction",
                weight_type = "rra", covariates = c("season", "year", "site"),
                unit_label = "scat")
prep <- dv_prepare(salish_seal_dna, spec, taxonomy = "table",
                   lineage = salish_seal_lineage, verbose = FALSE)
dv_rank_table(dv_tree(prep), "Family")[1:5, ]
#>           label value_item value_occ   pct_occ   value_w     pct_w
#> 84   Salmonidae          9      2308 19.826475  747.2801 16.157408
#> 49    Clupeidae          1      1948 16.733958 1023.0317 22.119605
#> 52 Merlucciidae          1      1755 15.076024 1089.1768 23.549770
#> 51      Gadidae          3       871  7.482175  228.2663  4.935487
#> 64     Cottidae         12       756  6.494287  234.4228  5.068601
```
