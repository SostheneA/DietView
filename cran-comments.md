## Submission summary

This is a new submission of DietView (version 0.1.0), a package for
interactive, hierarchical visualization of predator diet data, from stomach
contents to DNA metabarcoding.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: "WoRMS" (World Register of Marine
  Species, cited with its DOI), "GBIF" (Global Biodiversity Information
  Facility), "metabarcoding" (a standard term in molecular ecology), and
  "et al." in the reference to Thomas et al. (2022). All are correct.

## Test environments

* Local: Windows 11 x64, R 4.5.2, `R CMD check --as-cran`:
  0 errors | 0 warnings | 0 notes (apart from a local "unable to verify
  current time" note caused by the network)
* win-builder, R-release (4.6.2): 0 errors | 0 warnings | 1 note (new submission)
* win-builder, R-devel (2026-11-03 r90835): 0 errors | 0 warnings | 1 note (new submission)
* R-hub, linux (R-devel): 0 errors | 0 warnings | 0 notes
* R-hub, windows (R-devel): 0 errors | 0 warnings | 0 notes
* R-hub, macos (R-devel): 0 errors | 0 warnings | 0 notes
* R-hub, macos-arm64 (R-devel): 0 errors | 0 warnings | 0 notes

## Notes for the CRAN team

* "sunburst" in the Description is the name of a chart type, not a misspelling.
  'WoRMS', 'worrms', 'shiny' and 'plotly' are in single quotes as data source
  and software names.
* The suggested packages (worrms, shiny, DT, withr; rmarkdown for the
  vignettes) are used conditionally via requireNamespace(..., quietly = TRUE)
  in the code and testthat::skip_if_not_installed() in the tests; none is
  needed for the core pipeline.
* The optional taxonomy paths (dv_taxonomy_worms(), dv_taxonomy_gbif(),
  dv_prepare(taxonomy = "worms" / "gbif")) and the species-card photo lookups
  access the internet. Their examples are not run, the tests mock every
  network call, and the executed vignettes run offline on bundled data. The
  lookup caches are written to tools::R_user_dir("DietView", "cache") only
  when the user calls these functions; cache_dir = NULL disables them.
* Bundled data: the ICES example data (ICES Stomach Content Database, via the
  MIT-licensed R package stomachr) and the Salish Sea harbour seal DNA diet
  data (Thomas et al. 2022, Scientific Data, <doi:10.1038/s41597-022-01152-5>),
  released under CC0 1.0. Both are documented with their source.
* The examples of dv_build_html() and dv_deploy() write their HTML file to
  tempdir(). The dv_deploy() call itself is wrapped in \donttest{} because
  writing the self-contained dashboard took > 5 s elapsed (< 0.3 s CPU) on the
  local check.

## Reverse dependencies

None (new submission).
