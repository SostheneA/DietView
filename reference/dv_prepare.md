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
  stomachs = NULL,
  empty_col = NULL,
  gaps = c("label", "keep"),
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

- stomachs:

  Optional data.frame with one row per examined stomach, empty ones
  included (e.g.
  [ices_stomachs](https://sosthenea.github.io/DietView/reference/ices_stomachs.md)):
  the stomach column of the spec, plus optionally the predator and
  covariate columns and an empty flag (see `empty_col`). It is stored as
  `prep$stomachs` and lets
  [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
  report vacuity,
  [`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
  use all examined stomachs as the denominator, and
  [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
  add rows for empty stomachs. Without it, a long prey table holds only
  non-empty stomachs: %FO is over non-empty stomachs and the matrix has
  no empty rows. Stomachs of predators absent from `data` are ignored,
  so the full sampling frame can be passed with a subset of the
  predators. Stomachs whose records were all removed before
  `dv_prepare()` (e.g. they held only non-food items or nematodes) are
  counted neither as empty nor as examined; to count them as examined
  but empty, flag them empty in `stomachs` before calling
  `dv_prepare()`. Two checks warn once, with a count and up to three
  example ids: stomachs that have prey records but are absent from
  `stomachs` (counted as examined and non-empty), and stomachs whose
  predator in `stomachs` differs from the predator of their records (the
  predator of the records is used).

- empty_col:

  Optional column of `stomachs` flagging empty stomachs (logical, or
  0/1). With it, a stomach without records counts as empty only when
  flagged; one that is neither flagged nor in `data` has an unknown
  status and is left out of every count. Without it, every stomach of
  `stomachs` without a record in `data` counts as empty.

- gaps:

  How to show a rank that has no taxon in the lineage between two
  identified ranks: `"label"` (default) fills it with
  `"<ancestor> (no <rank>)"`, e.g. `"Polychaeta (no order)"`; `"keep"`
  leaves it `NA`, so its records sit under the unidentified node of that
  rank.

- verbose:

  Print progress and the validation summary.

## Value

An object of class `dietview_prep`: a list with `data`, `spec` (minus
any dropped covariates), `ranks`, `taxonomy_source` (the taxonomy path
actually used) and `taxonomy_log`. When `taxonomy = "worms"`,
`taxonomy_log` is the per-prey provenance table, with the attributes
`retrieved` (time of the run) and `worrms_version`; otherwise it is
`NULL`. The attribute `lineage_gaps` is a named integer vector: the
number of records whose rank was filled as a lineage gap, per rank. With
`stomachs`, the list also holds `stomachs`: the examined stomachs, with
their stomach, predator and covariate columns and a logical `empty_flag`
column.

## Details

With `taxonomy = "worms"`, each record is keyed by its AphiaID when it
has one and by its own prey name otherwise, so records without an
AphiaID never share a lineage by accident. Records with neither key stay
fully unidentified, with a warning.

Some groups have no taxon at a rank in WoRMS: several polychaete
families have no order, lancelets have no order and Priapulida have no
class. A record identified below such a rank would otherwise sit under
an `"NA"` node there and look unidentified. With `gaps = "label"` (the
default) that empty rank is filled with
`"<nearest named ancestor> (no <rank>)"`, e.g. `"Polychaeta (no order)"`
above Opheliidae; the sunburst draws it gray, not white, and its records
no longer inflate the unidentified share of that rank. Only ranks with
an identified rank below them are filled: a record identified to class
and no further keeps `NA` at order, family, genus and species, because
it is truly unidentified there. The number of filled cells per rank is
stored in the attribute `lineage_gaps`.

With `taxonomy = "table"`, the lineage table must hold each key once (a
duplicated key is an error), and prey keys absent from the table are
reported with a warning before their records are treated as fully
unidentified.

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
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 8530 
#>   stomachs  : 4222 
#>   predators : 22 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: region, year, quarter 
#>   source    : table 
if (FALSE) { # \dontrun{
# online: resolve prey against WoRMS (needs 'worrms' + internet)
prep_worms <- dv_prepare(dat, spec, taxonomy = "worms")
} # }
```
