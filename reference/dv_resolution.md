# Identification resolution: the finest rank each record reaches

For each record, the finest rank at which the prey was identified
(Kingdom, Phylum, ... Species, or unresolved), summarized as shares of
records and of weight, overall or by any grouping columns (predator,
year, region, a digestion stage, a method...). It says how much of the
material a figure at a given rank rests on, and makes visible where
identification stops: in a digested stomach, or where a metabarcoding
marker or reference library cannot separate species. A lineage gap
(`"<parent> (no <rank>)"`) is not counted as an identification at that
rank.

## Usage

``` r
dv_resolution(prep, by = NULL)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional grouping columns of `prep$data` (one or more), e.g.
  `prep$spec$predator` or `c("predator_common", "year")`.

## Value

A data.frame with the `by` columns, `finest_rank` (a factor, coarse to
fine, then "Unresolved"), `n_records`, `p_records`, `weight` and
`p_weight` (shares within each group; `p_weight` is `NA` without
weight).

## See also

[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md),
the same split by digestion stage.

## Examples

``` r
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
spec <- dv_spec(predator = "predator_common", stomach = "stomach_id",
                prey_id = "prey_aphia_id", prey_name = "prey_name",
                weight = "prey_weight_g", covariates = c("region", "year"))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
res <- dv_resolution(prep, by = "predator_common")
head(res)
#>   predator_common finest_rank n_records   weight p_records    p_weight
#> 1          Angler      Phylum        11  217.900 29.729730 12.82499503
#> 2          Angler       Order         4  202.953 10.810811 11.94525569
#> 3          Angler      Family         1    1.130  2.702703  0.06650869
#> 4          Angler     Species        12 1244.943 32.432432 73.27392282
#> 5          Angler  Unresolved         9   32.100 24.324324  1.88931776
#> 6    Atlantic cod      Phylum       231  314.894 10.026042  3.07917128
```
