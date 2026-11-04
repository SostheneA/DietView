# Resolve prey to the GBIF Backbone Taxonomy (key, exact name, then fuzzy)

The terrestrial and freshwater counterpart of
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md):
matches each unique prey to the GBIF Backbone Taxonomy, which covers all
kingdoms, and returns its lineage for the declared ranks. It follows the
same rules and returns the same provenance columns, so
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
and the rest of the package treat both sources alike. Matching proceeds
in this order:

1.  **id** - a GBIF taxon key is already known (`prey_id`). Its record
    is read: a synonym is followed to its accepted taxon
    (`"id_synonym"`) and the prey name stored with it is compared with
    the GBIF name (`name_check`). If the record cannot be read, the key
    is left unresolved for now (`"id_unchecked"`, `lineage_ok = FALSE`).
    A key GBIF does not know falls back to the prey name
    (`"id_fallback_name"`);

2.  **exact** - the GBIF species-match service finds the name as
    written;

3.  **fuzzy** - (if `fuzzy = TRUE`) the service proposes a close name,
    which can rescue a misspelling;

4.  **higherrank** - the name itself is unknown but a coarser taxon in
    it is (e.g. the genus of an unknown species); the lineage stops at
    that rank, so the record shows as unidentified below it. A step up
    to a kingdom alone (what GBIF answers for "Plastic" with
    `kingdom = "Animalia"`) is treated as no match;

5.  **unresolved** - nothing matched; all ranks stay `NA`.

A name can belong to several taxa (Polychaeta is a class of worms and a
genus of flies). GBIF then steps up to their shared ancestor, or gives
no match. DietView looks at the alternatives GBIF lists: when exactly
one of them is an exact match to an accepted name (in `kingdom`, if
given), it is taken; when several are, the conservative GBIF answer is
kept and the prey is flagged as a possible `homonym`, to be settled by a
lineage table. A name matched as a synonym gets the classification of
its accepted taxon. Every match type other than `"id"` and `"exact"`, a
name that differs from the GBIF name, a match below `min_confidence` and
a possible homonym are listed by
[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
for review.

## Usage

``` r
dv_taxonomy_gbif(
  keys,
  ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
  cache_dir = tools::R_user_dir("DietView", "cache"),
  fuzzy = TRUE,
  kingdom = NULL,
  min_confidence = 90,
  cache_max_age = 180,
  verbose = TRUE
)
```

## Arguments

- keys:

  Data.frame with columns `prey_id` (GBIF taxon key, may be `NA`) and
  `prey_name` (may be `NA`); one row per unique prey. Other columns are
  kept.

- ranks:

  Ranks to keep (default the seven flagship ranks). GBIF returns
  kingdom, phylum, class, order, family, genus and species; any other
  rank stays `NA`.

- cache_dir:

  Directory for the on-disk cache. `NULL` disables caching.

- fuzzy:

  If `TRUE` (default), accept fuzzy matches. `FALSE` asks GBIF for
  strict matching only.

- kingdom:

  Optional kingdom hint passed to GBIF (e.g. `"Animalia"`), which helps
  with names shared by a plant and an animal genus.

- min_confidence:

  GBIF confidence (0-100) below which a match is listed for review
  (default 90). The match is kept.

- cache_max_age:

  Maximum age, in days, of a cached lookup (default 180).

- verbose:

  Print progress.

## Value

`keys` with one column per rank plus `gbif_key`, `match_type` ("id",
"id_synonym", "id_unchecked", "id_fallback_name", "exact", "fuzzy",
"higherrank", "unresolved"), `name_check`, `matched_name`, `confidence`,
`n_candidates` (exact-name candidates GBIF listed), `homonym`,
`lineage_ok`, `retrieved` and `low_confidence`.

## Details

The GBIF Backbone has no class for some groups (ray-finned fishes, for
instance, sit directly under Chordata). With
`dv_prepare(gaps = "label")`, the default, such a missing rank is filled
as `"Chordata (no class)"` instead of looking unidentified.

Needs internet access to `api.gbif.org` and no extra package. Successful
lookups are cached to disk, in their own file next to the WoRMS cache,
with the same expiry rules (`cache_max_age`); failed lookups are never
cached and are retried on the next run,
`getOption("DietView.gbif_retries", 3)` times per request with a 1, 2, 4
... second backoff.

## See also

[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
for marine prey;
[`dv_parse_lineage()`](https://sosthenea.github.io/DietView/reference/dv_parse_lineage.md)
when the lineage already comes with the data (e.g. from a metabarcoding
pipeline).

## Examples

``` r
if (FALSE) { # \dontrun{
# needs internet access
keys <- data.frame(prey_id   = c(NA, 8084280),
                   prey_name = c("Crangon vulgaris", "Gadus morhua"))
dv_taxonomy_gbif(keys)
} # }
```
