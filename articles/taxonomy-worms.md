# Resolving prey taxonomy with WoRMS

DietView can attach a taxonomic lineage to every prey by querying the
[World Register of Marine Species
(WoRMS)](https://www.marinespecies.org/). This vignette shows how to run
the lookup, how to read the log of how each prey was matched, and how to
freeze the result so that later runs need no network. The lookup chunks
are shown but not run, because they need the `worrms` package and an
internet connection.

## Why a lineage, and why unidentified records stay

DietView shows the diet at seven ranks, kingdom to species, by default.
Your records rarely carry all seven: identification often stops at a
coarse rank (`Decapoda`, `Teleostei`). DietView never fills in the
missing ranks. Below the last rank reached, the record is shown as
unidentified at that rank, so every ring of the sunburst still holds all
the records and adds up to 100%.

## Running the lookup

`dv_prepare(taxonomy = "worms")` calls
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
once for each distinct prey key, not once per record.

``` r

library(DietView)

dat <- read.csv(
  system.file("extdata", "dietview_example.csv", package = "DietView"),
  na.strings = c("NA", "")
)
spec <- dv_spec(
  predator  = "predator_species_latin_name",
  stomach   = "stomach_id",
  prey_id   = "aphia_id",
  prey_name = "verified_name",
  weight    = "prey_weight"
)

prep <- dv_prepare(dat, spec, taxonomy = "worms")
prep
```

## How each prey is matched

Each distinct prey gets one row in the log, with a `match_type`:

| `match_type` | Meaning | What to do |
|----|----|----|
| `id` | The AphiaID is accepted in WoRMS | Nothing, unless `name_check` is `"differs"` |
| `id_synonym` | The AphiaID is unaccepted; its accepted ID was used | Check that the accepted name is the taxon you meant |
| `id_unchecked` | WoRMS could not be reached to check the ID | Run again later |
| `exact` | No ID; the name matched exactly | Nothing |
| `fuzzy` | No ID; the name was matched by TAXAMATCH, which tolerates misspellings | Check every one: a near match can be a different taxon |
| `unresolved` | No match | Correct the name, or accept that the prey stays unidentified |

Two more columns flag problems. `name_check` is `"differs"` when the
name in your table is not the name WoRMS holds for that AphiaID, which
usually means that one of the two was mistyped. `lineage_ok` is `FALSE`
when the prey was matched but WoRMS returned no classification, for
example because the connection failed. Those prey count as unidentified
at every rank until you run the lookup again. Failed lookups are not
stored in the cache, so the next run asks WoRMS again.

Successful lookups are cached on disk (in
`tools::R_user_dir("DietView", "cache")`), so a rerun only queries what
changed. The log also records when the taxonomy was retrieved and which
`worrms` version was used, in its `retrieved` and `worrms_version`
attributes.

## Reading the report

[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
returns the prey that need a look, largest number of records first:

``` r

review <- dv_taxonomy_report(prep, which = "review")
review

# the whole log, to archive or to send to a co-author
dv_taxonomy_report(prep, which = "all", file = file.path(tempdir(), "taxonomy_log.csv"))
```

A frozen copy of this log (`dietview_example_worms_log.csv`) is not
included in this build of the package, so the chunk below is not run.

``` r

wlog <- read.csv(log_file, na.strings = c("NA", ""))
wlog[, intersect(c("prey_name", "prey_id", "match_type", "name_check",
                   "matched_name", "n_records", "lineage_ok"), names(wlog))]
```

On this table, “unidentified material” has neither an AphiaID nor a
taxonomic name, so it is `unresolved`, and its records are unidentified
at every rank. That is expected. Unresolved prey you did not expect are
the ones to chase.

## Correcting and freezing

Fix the names or IDs the report lists in your source table and run the
lookup again. When the log is clean, save the lineage and switch to the
offline path for every later run:

``` r

lineage <- unique(prep$data[, c(spec$prey_name, prep$ranks)])
write.csv(lineage, "lineage_2026-10-20.csv", row.names = FALSE)

lineage <- read.csv("lineage_2026-10-20.csv", na.strings = c("NA", ""))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage)
```

The lineage table fixes the taxonomic snapshot your figures were made
from. Archive it with your data, and note the retrieval date and the
`worrms` version, because WoRMS changes.

## Exact matching only

To turn off TAXAMATCH matching and keep only known AphiaIDs and exact
names:

``` r

prep <- dv_prepare(dat, spec, taxonomy = "worms", fuzzy = FALSE)
```
