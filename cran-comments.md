## Submission summary

This is a new submission of DietView (version 0.1.0), a package for
interactive, hierarchical visualization of predator diet from stomach-content
data.

## R CMD check results

0 errors | 0 warnings | 0 notes

* On CRAN's incoming checks the NOTE "New submission" is expected.

## Test environments

* Local: Windows 11 x64 (build 26100), R 4.5.2

## Notes for the CRAN team

* "sunburst" in the Description is the name of a chart type, not a misspelling.
  'WoRMS', 'worrms', 'shiny' and 'plotly' are in single quotes as data source
  and software names.
* The suggested packages (worrms, shiny, DT, rmarkdown, withr) are used
  conditionally via requireNamespace(..., quietly = TRUE) in the code and
  testthat::skip_if_not_installed() in the tests; none is needed for the core
  pipeline.
* The optional WoRMS taxonomy path (dv_taxonomy_worms(), dv_prepare(taxonomy =
  "worms")) and the species-card photo lookups access the internet. Their
  examples are not run, the tests mock every network call, and the executed
  vignettes run offline on bundled data. The WoRMS cache is written to
  tools::R_user_dir("DietView", "cache") only when the user calls these
  functions; cache_dir = NULL disables it.
* The examples of dv_build_html() and dv_deploy() write their HTML file to
  tempdir().

## Reverse dependencies

None (new submission).
