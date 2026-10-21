# Review doubtful prey matches

Returns the prey whose taxonomy needs a human eye: fuzzy matches (WoRMS
TAXAMATCH proposed a close-but-not-identical name), unresolved prey (no
match), AphiaIDs that WoRMS treats as unaccepted (`"id_synonym"`,
followed to the accepted one) or whose record could not be read
(`"id_unchecked"`), AphiaIDs whose stored name differs from the WoRMS
name (`name_check = "differs"`), names with several accepted WoRMS
records (`homonym`), and matches for which WoRMS returned no
classification (`lineage_ok = FALSE`, usually a network or server error;
run again to retry). Use it to audit the enrichment, then correct
anything wrong by supplying a lineage table
(`dv_prepare(taxonomy = "table")`) or fixing the source names.

## Usage

``` r
dv_taxonomy_report(
  prep,
  which = c("review", "fuzzy", "unresolved", "all"),
  file = NULL
)
```

## Arguments

- prep:

  A `dietview_prep` produced with `taxonomy = "worms"`.

- which:

  Which rows to return: "review" (every doubtful row listed above, the
  default), "fuzzy", "unresolved", or "all".

- file:

  Optional CSV path to write the report to.

## Value

A data.frame with the prey name, the names seen under that key, what
WoRMS matched, the match type and checks, the AphiaID used, the number
of records affected, and the resolved ranks, sorted by number of
records.

## Examples

``` r
if (FALSE) { # \dontrun{
# a WoRMS-prepared object carries a taxonomy log to review
prep <- dv_prepare(dat, spec, taxonomy = "worms")
dv_taxonomy_report(prep, which = "review")
} # }
```
