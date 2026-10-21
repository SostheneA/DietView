# Deploy the dashboard as a standalone HTML file

Thin wrapper over
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
that writes the self-contained dashboard into `dir` (e.g. a folder
served by your web platform) and returns its path.

## Usage

``` r
dv_deploy(prep, file = "dietview_dashboard.html", dir = ".", ...)
```

## Arguments

- prep:

  A `dietview_prep`.

- file:

  Output file name.

- dir:

  Destination directory (created if needed).

- ...:

  Passed to
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md).

## Value

The output path, invisibly.

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
dv_deploy(prep_cod, file = "cod_dashboard.html", dir = tempdir(),
          strata = character(0), bands = "count", self_contained = FALSE)
#> Deployed standalone dashboard: C:/Users/SOSTHENEA/AppData/Local/Temp/1/RtmpQVRMw4/cod_dashboard.html
```
