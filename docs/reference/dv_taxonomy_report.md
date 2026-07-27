# Review fuzzy and unresolved prey matches

Returns the prey whose taxonomy needs a human eye: fuzzy matches (WoRMS
proposed a close-but-not-identical name) and unresolved prey (no match).
Use it to audit the enrichment, then correct anything wrong by supplying
a lineage table (`dv_prepare(taxonomy = "table")`) or fixing the source
names.

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

  Which rows to return: "review" (fuzzy + unresolved, the default),
  "fuzzy", "unresolved", or "all".

- file:

  Optional CSV path to write the report to.

## Value

A data.frame with the prey name, what WoRMS matched, the match type, the
AphiaID used, the number of records affected, and the resolved ranks.

## Examples

``` r
if (FALSE) { # \dontrun{
# a WoRMS-prepared object carries a taxonomy log to review
prep <- dv_prepare(dat, spec, taxonomy = "worms")
dv_taxonomy_report(prep, which = "review")
} # }
```
