# Identification resolution versus digestion level

Quantifies the identification bias linked to digestion: for each
digestion level, the share of records (and of weight) whose finest
resolved rank is Kingdom, Phylum, ... Species, or unresolved. As
digestion advances, mass shifts toward the coarse ranks – this makes the
bias explicit instead of hiding it inside a functional grouping.

## Usage

``` r
dv_digestion_diagnostic(prep, by = NULL)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional covariate to split the diagnostic by (e.g. "period").

## Value

A data.frame with columns `digestion`, optional `by`, `finest_rank`,
`n_records`, `p_records`, `weight`, `p_weight`.

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

# digestion labels in ices_diet are inferred from the older ICES format;
# see ?ices_diet
head(dv_digestion_diagnostic(prep_cod))
#>    digestion finest_rank n_records   weight  p_records     p_weight
#> 1 0 pristine      Phylum         1    0.123  0.6289308  0.008477275
#> 2 0 pristine       Class         3    3.721  1.8867925  0.256454790
#> 3 0 pristine       Order         9   28.566  5.6603774  1.968795359
#> 4 0 pristine      Family        11   42.063  6.9182390  2.899021185
#> 5 0 pristine       Genus         7   14.100  4.4025157  0.971785149
#> 6 0 pristine     Species       109 1362.365 68.5534591 93.895466243
```
