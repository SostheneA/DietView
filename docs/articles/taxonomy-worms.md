# Resolving prey taxonomy with WoRMS

DietView can attach a full taxonomic lineage to your prey by querying
the [World Register of Marine Species
(WoRMS)](https://www.marinespecies.org/). This article explains how the
matching works, what provenance it records, and how to review and
correct it. All chunks here are shown but not run (they need the
`worrms` package and internet).

## Why a lineage, and why NA matters

DietView renders diet across the seven flagship Linnaean ranks (kingdom
… species). Your records rarely carry all seven, and identification
often stops at a coarse rank (e.g. `Decapoda`, `Teleostei`). DietView
never invents the missing ranks: where identification stops, the deeper
ranks stay `NA` and are shown as an explicit “NA” category so
within-rank percentages still sum to 100 %.

## The matching strategy

`dv_prepare(taxonomy = "worms")` calls
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
on the unique prey. Matching proceeds in a strict order and every prey
carries a provenance record:

1.  **id** - the `prey_id` (AphiaID) is already known and used directly;
2.  **exact** - the `prey_name` matches a WoRMS latin name exactly;
3.  **fuzzy** - if `fuzzy = TRUE`, the closest WoRMS name is proposed
    (and flagged);
4.  **unresolved** - nothing matched; all ranks stay `NA`.

Unaccepted names are followed to their **accepted (valid) AphiaID**
before the lineage is fetched, and results are cached to disk so re-runs
and other surveys do not requery.

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

prep <- dv_prepare(dat, spec, taxonomy = "worms")   # id / exact / fuzzy / unresolved
prep
```

## Reviewing fuzzy and unresolved matches

Nothing is guessed silently.
[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
returns exactly the prey that need a human eye, sorted by how many
records they affect.

``` r
review <- dv_taxonomy_report(prep, which = "review")   # fuzzy + unresolved
review

# write it out for a co-author to check
dv_taxonomy_report(prep, which = "all", file = "taxonomy_log.csv")
```

## Correcting what is wrong

Once you have reviewed the report, fix the source names, or freeze a
curated lineage table and switch to the offline, reproducible path:

``` r
lineage <- read.csv("my_curated_lineage.csv", na.strings = c("NA", ""))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage)
```

## Exact-only, conservative matching

To disable fuzzy matching entirely (exact names and known AphiaIDs
only):

``` r
prep <- dv_prepare(dat, spec, taxonomy = "worms", fuzzy = FALSE)
```
