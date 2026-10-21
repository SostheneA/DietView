# Sampled stomachs of the ICES example data, empty ones included

One row per stomach sampled in the hauls of
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md):
8,886 stomachs of 23 predator species, of which 1,197 are flagged empty.
Stomachs without any prey record do not appear in
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md),
so this table is the one to use for the proportion of empty stomachs or
the number of fish sampled per stratum.

## Usage

``` r
ices_stomachs
```

## Format

A data frame with 8,886 rows and 20 columns: `stomach_id`, `haul_id`,
`country`, `survey`, `year`, `month`, `quarter`, `lat`, `lon`,
`ices_rectangle`, `depth_m`, `region`, `predator_aphia_id`,
`predator_latin`, `predator_common`, `n_fish_pooled`, `length_cm`,
`weight_g`, `stomach_empty`, `regurgitated` (as in
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md)).

## Source

As
[ices_diet](https://sosthenea.github.io/DietView/reference/ices_diet.md).

## Examples

``` r
# share of stomachs flagged empty, by predator
e <- tapply(ices_stomachs$stomach_empty %in% 1, ices_stomachs$predator_common, mean)
round(100 * sort(e, decreasing = TRUE), 1)[1:5]
#>      Twaite shad       Blonde ray           Turbot Atlantic halibut 
#>            100.0             50.0             40.0             33.3 
#>  European plaice 
#>             30.1 
```
