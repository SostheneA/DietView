# Frequency of occurrence per rank (the Buckland Table B1 layout)

The classical frequency of occurrence (%FO): the proportion of non-empty
stomachs that contain each taxon, computed INDEPENDENTLY at each
taxonomic rank. Because a stomach can contain several categories, and
because a parent's %FO is recomputed from stomach presence rather than
summed from its children, these values are non-additive across ranks -
which is exactly why they are reported as a nested hierarchy of levels
(Buckland et al., 2017). This is distinct from the share of prey records
in
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
(`pct_occ`), which is additive so that it can be drawn as a sunburst:
the two agree only where each stomach holds at most one record of the
taxon, which rarely holds at coarse ranks. Stomach identifiers must be
unique across predators (see
[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)).

## Usage

``` r
dv_fo_table(prep, rank = NULL, by = NULL, include_na = TRUE)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- rank:

  A single rank (e.g. `"genus"`) or `NULL` for every rank stacked.

- by:

  Optional covariate to compute %FO within each level of.

- include_na:

  Keep the explicit unidentified category at each rank.

## Value

A data.frame with (optional) `by`, `rank`, `taxon`, `n_stomachs`
(stomachs containing the taxon), `n_total` (stomachs in the group), and
`pct_fo`.

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
# Atlantic cod only, for speed
cod <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)
dv_fo_table(prep_cod, rank = "class")
#>     rank        taxon n_stomachs n_total pct_fo
#> 1  class Malacostraca        618     991  62.36
#> 2  class    Teleostei        332     991  33.50
#> 3  class           NA        323     991  32.59
#> 4  class   Polychaeta        136     991  13.72
#> 5  class  Ophiuroidea         49     991   4.94
#> 6  class     Bivalvia         28     991   2.83
#> 7  class   Gastropoda         18     991   1.82
#> 8  class  Cephalopoda         10     991   1.01
#> 9  class     Gephyrea          2     991   0.20
#> 10 class       Myxini          1     991   0.10
#> 11 class    Trematoda          1     991   0.10
```
