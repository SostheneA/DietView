# Resolve prey to the WoRMS classification (exact, then optional fuzzy)

Matches each unique prey to the World Register of Marine Species and
returns its lineage for the declared ranks. Matching proceeds in this
order:

1.  **id** - the AphiaID is already known (`prey_id`), used directly;

2.  **exact** - the prey name matches a WoRMS name exactly;

3.  **fuzzy** - (if `fuzzy = TRUE`) the closest WoRMS name is proposed;

4.  **unresolved** - nothing matched; all ranks stay `NA`.

Unaccepted names are followed to their accepted (valid) AphiaID before
the lineage is fetched. Every prey carries a provenance record
(`match_type`, `matched_name`, `aphia_used`) so fuzzy hits can be
reviewed and corrected - see
[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md).
Nothing is ever guessed silently: a fuzzy match is flagged, and an
unresolved prey keeps `NA` ranks and shows up as the explicit "NA"
category downstream.

## Usage

``` r
dv_taxonomy_worms(
  keys,
  ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
  cache_dir = tools::R_user_dir("DietView", "cache"),
  fuzzy = TRUE,
  marine_only = TRUE,
  verbose = TRUE
)
```

## Arguments

- keys:

  Data.frame with columns `prey_id` (AphiaID, may be NA) and `prey_name`
  (may be NA); one row per unique prey.

- ranks:

  Ranks to keep (default the seven flagship ranks).

- cache_dir:

  Directory for the on-disk cache. `NULL` disables caching.

- fuzzy:

  If `TRUE` (default), fall back to WoRMS fuzzy name matching when the
  exact name fails. Set `FALSE` for exact-only, conservative matching.

- marine_only:

  Restrict WoRMS name matching to marine taxa.

- verbose:

  Print progress.

## Value

`keys` with one column per rank plus `aphia_used`, `match_type` ("id",
"exact", "fuzzy", "unresolved") and `matched_name`.

## Details

Requires the worrms package and internet access. Results are cached to
disk, so re-runs and other surveys do not requery.

## Examples

``` r
if (FALSE) { # \dontrun{
# needs the 'worrms' package and internet access
keys <- data.frame(
  prey_id   = c(NA, NA),
  prey_name = c("Gadus morhua", "Homarus americanus"),
  stringsAsFactors = FALSE
)
dv_taxonomy_worms(keys)
} # }
```
