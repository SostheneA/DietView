# Prepare a diet table for DietView (validate + add taxa)

Validates the long table with
[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
and attaches the taxonomic lineage for the declared ranks. The taxonomy
can come from:

- `"columns"` - the rank columns are already in `data`;

- `"worms"` - fetch the lineage from WoRMS by AphiaID/name;

- `"table"` - join a lineage table you supply via `lineage`;

- `"auto"` - use columns if present, else `lineage` if given, else
  WoRMS.

Ranks that cannot be resolved are kept as `NA` and later shown as an
explicit unidentified category below the deepest identified rank – never
dropped.

## Usage

``` r
dv_prepare(
  data,
  spec,
  taxonomy = c("auto", "columns", "worms", "table"),
  lineage = NULL,
  fuzzy = TRUE,
  cache_dir = tools::R_user_dir("DietView", "cache"),
  cache_max_age = 180,
  strict_covariates = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  A data.frame (the long diet table).

- spec:

  A `dietview_spec` from
  [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).

- taxonomy:

  One of "auto", "columns", "worms", "table".

- lineage:

  For `taxonomy = "table"`: a data.frame with a key column (`prey_id` or
  `prey_name`, matching your spec) plus one column per rank.

- fuzzy:

  For `taxonomy = "worms"`: when the exact name fails, try WoRMS
  TAXAMATCH fuzzy matching (default `TRUE`). Fuzzy hits are flagged,
  never silent - review them with
  [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md).

- cache_dir:

  Cache directory for the WoRMS path. `NULL` disables caching.

- cache_max_age:

  For the WoRMS path: cached lookups older than this many days are
  fetched again (default 180). See
  [`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md).

- strict_covariates:

  Passed to
  [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md):
  if `TRUE` (default) a declared covariate missing from `data` is an
  error; if `FALSE` it is dropped from the returned spec with a warning.

- verbose:

  Print progress and the validation summary.

## Value

An object of class `dietview_prep`: a list with `data`, `spec` (minus
any dropped covariates), `ranks`, `taxonomy_source` (the taxonomy path
actually used) and `taxonomy_log`. When `taxonomy = "worms"`,
`taxonomy_log` is the per-prey provenance table, with the attributes
`retrieved` (time of the run) and `worrms_version`; otherwise it is
`NULL`.

## Details

With `taxonomy = "worms"`, each record is keyed by its AphiaID when it
has one and by its own prey name otherwise, so records without an
AphiaID never share a lineage by accident. Records with neither key stay
fully unidentified, with a warning.

With `taxonomy = "table"`, the lineage table must hold each key once (a
duplicated key is an error), and prey keys absent from the table are
reported with a warning before their records are treated as fully
unidentified.

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id",
                prey_id = "aphia_id",
                prey_name = "verified_name",
                weight = "prey_weight")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 24 
#>   stomachs  : 11 
#>   predators : 3 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates:  
#>   source    : table 
if (FALSE) { # \dontrun{
# online: resolve prey against WoRMS (needs 'worrms' + internet)
prep <- dv_prepare(dat, spec, taxonomy = "worms")
} # }
```
