# Declare how your columns map to DietView's roles

DietView never hard-codes column names. You describe your long table
once with `dv_spec()`, then pass the spec to every other function. One
row of the table must be one prey record in a stomach.

## Usage

``` r
dv_spec(
  predator,
  stomach,
  prey_name = NULL,
  prey_id = NULL,
  weight = NULL,
  count = NULL,
  digestion = NULL,
  covariates = character(0),
  ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
  predator_latin = NULL
)
```

## Arguments

- predator:

  Column with the predator name/species.

- stomach:

  Column with the stomach identifier (unit of occurrence).

- prey_name:

  Column with the prey latin name (used if `prey_id` is missing).

- prey_id:

  Column with the WoRMS AphiaID of the prey (preferred key).

- weight:

  Column with prey weight (for the weight currency). Optional.

- count:

  Column with the number of prey individuals. Optional; if absent, one
  occurrence = one record.

- digestion:

  Column with the digestion level (enables digestion diagnostics).
  Optional.

- covariates:

  Character vector of covariate columns to allow as strata (e.g.
  `c("period", "year", "size_class")`).

- ranks:

  Taxonomic ranks to display, coarse to fine. Defaults to the seven
  flagship ranks kingdom..species. If your table already carries these
  columns, keep the default; otherwise they are filled by
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- predator_latin:

  Optional column with the predator Latin name (used to auto-fetch
  identification photos).

## Value

An object of class `dietview_spec`.

## Examples

``` r
spec <- dv_spec(
  predator = "predator_species_common_name",
  stomach  = "stomach_id",
  prey_id  = "aphia_id",
  prey_name = "verified_name",
  weight   = "prey_weight",
  covariates = c("period", "size_class")
)
spec$ranks
#> [1] "kingdom" "phylum"  "class"   "order"   "family"  "genus"   "species"
```
