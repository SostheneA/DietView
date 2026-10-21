# Resolve prey to the WoRMS classification (id, exact name, then fuzzy)

Matches each unique prey to the World Register of Marine Species and
returns its lineage for the declared ranks. Matching proceeds in this
order:

1.  **id** - the AphiaID is already known (`prey_id`). Its WoRMS record
    is read: an unaccepted AphiaID is followed to its accepted (valid)
    one (`"id_synonym"`), and the prey name stored with it is compared
    with the name WoRMS gives that AphiaID (`name_check`: "agrees" or
    "differs"). If the record cannot be read, the AphiaID is used as
    given (`"id_unchecked"`);

2.  **exact** - the prey name matches a WoRMS name exactly;

3.  **fuzzy** - (if `fuzzy = TRUE`) WoRMS TAXAMATCH
    ([`worrms::wm_records_taxamatch()`](https://docs.ropensci.org/worrms/reference/wm_records_taxamatch.html))
    proposes the closest name, which can rescue a misspelling;

4.  **unresolved** - nothing matched; all ranks stay `NA`.

Unaccepted names are followed to their accepted (valid) AphiaID before
the lineage is fetched. Every prey carries a provenance record
(`match_type`, `name_check`, `matched_name`, `aphia_used`,
`n_candidates`, `homonym`, `lineage_ok`, `retrieved`) so doubtful
matches can be reviewed and corrected - see
[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md).
Nothing is guessed silently: a fuzzy match is flagged, a name with
several accepted WoRMS records is flagged as a possible homonym, and an
unresolved prey keeps `NA` ranks and shows up as the explicit
unidentified category downstream.

## Usage

``` r
dv_taxonomy_worms(
  keys,
  ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
  cache_dir = tools::R_user_dir("DietView", "cache"),
  fuzzy = TRUE,
  marine_only = TRUE,
  cache_max_age = 180,
  verbose = TRUE
)
```

## Arguments

- keys:

  Data.frame with columns `prey_id` (AphiaID, may be NA) and `prey_name`
  (may be NA); one row per unique prey. Other columns are kept.

- ranks:

  Ranks to keep (default the seven flagship ranks).

- cache_dir:

  Directory for the on-disk cache. `NULL` disables caching.

- fuzzy:

  If `TRUE` (default), fall back to WoRMS TAXAMATCH fuzzy name matching
  when the exact name fails. Set `FALSE` for exact-only, conservative
  matching.

- marine_only:

  Restrict WoRMS name matching to marine taxa.

- cache_max_age:

  Maximum age, in days, of a cached lookup before it is fetched again
  (default 180). `Inf` trusts the cache forever.

- verbose:

  Print progress.

## Value

`keys` with one column per rank plus `aphia_used`, `match_type` ("id",
"id_synonym", "id_unchecked", "exact", "fuzzy", "unresolved"),
`name_check`, `matched_name`, `n_candidates` (WoRMS records returned for
a name), `homonym` (more than one accepted record for that name),
`lineage_ok` (`TRUE`/`FALSE` once a classification was requested, `NA`
otherwise) and `retrieved` (date the lineage was fetched from WoRMS).

## Details

Requires the worrms package and internet access. Successful lookups are
cached to disk, so re-runs and other surveys do not requery. Failed
lookups (timeout, no network, server error, an AphiaID WoRMS does not
know) are never cached: they are flagged with `lineage_ok = FALSE` and a
warning, and are retried on the next run. Cache entries written by
DietView 0.1.0, which carry no date, are fetched again; the empty
lineages it cached after failed lookups are discarded. The cache file is
written even if the run is interrupted.

## Examples

``` r
if (FALSE) { # \dontrun{
# needs the 'worrms' package and internet access
keys <- data.frame(
  prey_id   = c(126436, NA),
  prey_name = c("Gadus morhua", "Crangon crangon"),
  stringsAsFactors = FALSE
)
dv_taxonomy_worms(keys)

# the prey keys of the ICES cod records
cod <- ices_diet[ices_diet$predator_common == "Atlantic cod", ]
keys <- unique(data.frame(prey_id = cod$prey_aphia_id,
                          prey_name = cod$prey_name))
lin <- dv_taxonomy_worms(keys)
table(lin$match_type)
} # }
```
