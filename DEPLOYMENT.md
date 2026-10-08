# Deploying DietView (GitHub + r-universe + pkgdown)

Same setup as RHISEA. Do the steps in order.

## 0. One manual edit you must make

The maintainer email is the only thing that cannot be auto-filled —
r-universe and CRAN reject a package without a resolvable maintainer.
Replace the placeholder in **both** files:

- `DESCRIPTION` → `Authors@R` → `email = "REPLACE_WITH_REAL@email.org"`
- `CITATION.cff` → `email:`

(Optional) confirm the author string `CADI Gulf Center` is how you want
the group named, in `DESCRIPTION`, `CITATION.cff`, and `inst/CITATION`.

## 1. Regenerate the documentation (required once)

The roxygen sources use markdown links (`[dv_spec()]`) and `DESCRIPTION`
now sets `Roxygen: list(markdown = TRUE)`. Regenerate so the `man/*.Rd`
links and `NAMESPACE` are rebuilt correctly:

``` r

# from the package root
install.packages(c("roxygen2", "devtools"))   # if needed
devtools::document()      # rebuilds man/ + NAMESPACE
```

## 2. Local check (recommended)

``` r

devtools::check()         # R CMD check
devtools::build_readme()  # optional
```

If the `Getting started` vignette errors during checks on CI, set
`eval = FALSE` at the top of `vignettes/dietview.Rmd` and re-run (the
other two vignettes are already non-executed).

## 2b. Build the docs locally (works with a private repo)

You do not need to publish anything to see the site: pkgdown builds it
into `docs/`, which you open in your browser.

``` r

install.packages(c("pkgdown", "pagedown"))   # once


pkgdown::preview_site()        # opens docs/ in your browser
```

`dev/build_docs.R` re-renders `docs/DietView-technical-reference.pdf`
**from the built article**, so the PDF can never drift from the web
version. The same step runs in the `pkgdown` GitHub Action, so the
published PDF is refreshed on every deploy. (`pagedown` uses headless
Chrome – no LaTeX required. If Chrome is missing the site still builds
and only the PDF is skipped.)

Note: `docs/` is git-ignored on purpose – it is a build artifact.

## 3. Push to GitHub

Create the repo **SostheneA/DietView** (public), then:

``` bash
git init
git add .
git commit -m "DietView 0.1.0"
git branch -M main
git remote add origin https://github.com/SostheneA/DietView.git
git push -u origin main
```

The push triggers the two workflows: `R-CMD-check` and `pkgdown`.

## 4. Turn on GitHub Pages

After the first successful `pkgdown` run (it creates a `gh-pages`
branch):

Repo **Settings → Pages → Build and deployment → Source: Deploy from a
branch → Branch: `gh-pages` / `(root)`**.

The site appears at **<https://sosthenea.github.io/DietView/>**.

## 5. Register the package in your r-universe

Edit the `packages.json` in the control repo that already lists RHISEA
(the repo named `SostheneA.r-universe.dev`, linked from your universe
page). Add the entry:

``` json
{ "package": "DietView", "url": "https://github.com/SostheneA/DietView" }
```

Commit and push. r-universe rebuilds automatically; DietView then
appears at **<https://sosthenea.r-universe.dev/DietView>** with source +
binaries and an auto-generated citation (from `CITATION.cff`), just like
RHISEA.

## 6. Verify

- Builds: <https://sosthenea.r-universe.dev/builds>
- Package: <https://sosthenea.r-universe.dev/DietView>
- Docs: <https://sosthenea.github.io/DietView/>
- Install test:

``` r

install.packages("DietView",
  repos = c("https://sosthenea.r-universe.dev", "https://cloud.r-project.org"))
```
