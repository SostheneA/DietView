## Submission summary

This is a new submission of DietView (version 0.1.0), a package for
interactive, hierarchical visualization of predator diet from stomach-content
data.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* "WoRMS" is flagged as a possibly misspelled word in DESCRIPTION. It is the
  acronym of the World Register of Marine Species, cited with its DOI.

## Test environments

* Local: Windows 11 x64 (build 26100), R 4.5.2, `R CMD check --as-cran`:
  0 errors | 0 warnings | 1 note ("New submission")
* win-builder, R-devel (2026-11-02 r90827 ucrt): 0 errors | 0 warnings | 1 note
* win-builder, R-release (4.6.2): 0 errors | 0 warnings | 1 note
* mac-builder, R-release: not run (service returned HTTP 502 on repeated attempts)
* R-hub, linux (Ubuntu 26.04, R-devel r90825): 0 errors | 0 warnings | 0 notes
* R-hub, windows (Windows Server 2022, R-devel r90825): 0 errors | 0 warnings | 0 notes
* R-hub, macos-arm64 (R-devel r90825): 0 errors | 0 warnings | 0 notes
* R-hub, macos x86_64 (R-devel r90827): 0 errors | 0 warnings | 0 notes

## Notes for the CRAN team

* "sunburst" in the Description is the name of a chart type, not a misspelling.
  'WoRMS', 'worrms', 'shiny' and 'plotly' are in single quotes as data source
  and software names.
* The suggested packages (worrms, shiny, DT, withr; rmarkdown for the
  vignettes) are used
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
  The dv_deploy() call itself is wrapped in \donttest{} because writing the
  self-contained dashboard took > 5 s elapsed (< 0.3 s CPU) on the local check.

## Reverse dependencies

None (new submission).
