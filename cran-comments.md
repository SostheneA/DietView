## Submission summary

This is a new submission of DietView, a package for interactive, taxonomically
complete visualization of predator diet from stomach-content data.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release, so the only NOTE is the expected "New submission".

## Test environments

* Local: <your OS>, R <your R version>
* win-builder: devel and release
* macOS-builder (mac.r-project.org)
* GitHub Actions: ubuntu-latest (devel, release, oldrel-1), macOS-latest, windows-latest
* R-hub: linux, windows, macos

## Notes for the CRAN team

* Possibly misspelled words in DESCRIPTION are intentional domain terms, data
  sources, and software names: "AphiaID", "WoRMS", "covariate(s)", "plotly",
  "shiny", "sunburst", "taxonomically". "WoRMS", "shiny", and "plotly" are given
  in single quotes as required for data sources and software.
* The package uses several suggested packages (worrms, shiny, DT, rmarkdown).
  All of them are used conditionally via requireNamespace(..., quietly = TRUE);
  none are needed for the core pipeline, tests, or the executed vignettes.
* The optional WoRMS taxonomy path (dv_taxonomy_worms(), dv_prepare(taxonomy =
  "worms")) and the species-card photo lookups access the internet. They are
  never triggered in examples, tests, or the executed vignettes, and their cache
  defaults to tools::R_user_dir("DietView", "cache"). The tests and the rendered
  vignettes run fully offline on bundled example data.
* dv_build_html()/dv_deploy() write an HTML file to a user-specified location;
  they are not called in examples, tests, or executed vignettes.

## Reverse dependencies

None (new submission).
