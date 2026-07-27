# CRAN submission checklist for DietView

The package is now CRAN-shaped. What was done, and what you still do.

## Already done (in this repo)

- **`R CMD check` cleared** (was 1 error / 1 warning / 3 notes):
  - removed `man/hello.Rd` (orphan doc → the `hello()` example ERROR + the
    code/doc-mismatch WARNING);
  - dropped unused `Imports` (`grDevices`, `rlang`, `tidyr`) → the "declared
    Imports should be used" NOTE;
  - added `utils::globalVariables()` for dplyr data-masking column names
    (`value_item`, `occ`, `w`, `n_records`, `weight`) → the "no visible binding"
    NOTE;
  - moved the plotly-heavy executed vignettes to `vignettes/articles/` (site-only,
    not shipped) → the 11.4 Mb "installed size" INFO drops well under the limit.
  - The remaining "unable to verify current time" NOTE is environmental (no
    network to the time server during the check) and is ignored by CRAN.
- **Title** rewritten to CRAN rules: title case, no "package", no package name,
  no "An R package for", no trailing period.
- **Description** rewritten as complete sentences; software and data sources in
  single quotes ('WoRMS', 'shiny', 'plotly'); "WoRMS" expanded; does not start
  with the package name or "This package".
- **Non-ASCII removed** from all R sources (em-dashes → hyphens).
- **Suggests are conditional** (worrms, shiny, DT, rmarkdown), guarded with
  requireNamespace(..., quietly = TRUE).
- **Tests and executed vignettes run offline** on bundled data only.
- **Runnable `@examples` on every exported function**: offline examples on the
  bundled data (executed at check), with network / interactive / file-writing
  paths under `\dontrun{}` or `if (interactive())` and any file output sent to
  `tempdir()`.
- `cran-comments.md` provided.

## You must do before submitting

1. **Maintainer email** -- replace `REPLACE_WITH_REAL@email.org` in `DESCRIPTION`
   (and `CITATION.cff`). CRAN emails the maintainer to confirm; it must be real
   and monitored.
2. **Regenerate docs**: `devtools::document()` (rebuilds man/ + NAMESPACE from the
   markdown roxygen and the ASCII fixes).
3. **Push the GitHub repo first** so the DESCRIPTION URLs resolve (CRAN NOTEs
   404s). `SostheneA/DietView` and the pkgdown site should be live.
4. **Run the checks**:
   ```r
   devtools::check()                    # 0 errors / 0 warnings / 1 note is fine
   devtools::check_win_devel()          # win-builder
   rhub::rhub_check()                   # multi-platform
   urlchecker::url_check()              # confirms every URL resolves
   ```
5. **Fill in `cran-comments.md`** test environments with what you actually ran.
6. **Submit**: `devtools::release()` (guided) or the web form at
   https://cran.r-project.org/submit.html. Reply to the confirmation email.

## Optional but recommended

- **ORCIDs** in `Authors@R` via `comment = c(ORCID = "....")`.
- **A CITATION with the article** once the paper has a DOI.

## Note on r-universe vs CRAN wording

The CRAN-clean Title/Description also works on r-universe, so the DESCRIPTION now
serves both. The longer, descriptive phrasing you liked ("... interactive,
taxonomically complete diet visualization from stomach-content data") is kept as
free text on the site (pkgdown home description and the README heading), where
CRAN's Title rules do not apply.
