# Deploy the dashboard as a standalone HTML file

Thin wrapper over
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
that writes the self-contained dashboard into `dir` (e.g. a folder
served by your web platform) and returns its path.

## Usage

``` r
dv_deploy(prep, file = "dietview_dashboard.html", dir = ".", ...)
```

## Arguments

- prep:

  A `dietview_prep`.

- file:

  Output file name.

- dir:

  Destination directory (created if needed).

- ...:

  Passed to
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md).

## Value

The output path, invisibly.

## Examples

``` r
csv <- system.file("extdata", "dietview_example.csv", package = "DietView")
lin <- system.file("extdata", "dietview_example_lineage.csv", package = "DietView")
dat <- read.csv(csv, na.strings = c("NA", ""))
lineage <- read.csv(lin, na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name",
                stomach = "stomach_id",
                prey_id = "aphia_id",
                prey_name = "verified_name",
                weight = "prey_weight")
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage,
                   verbose = FALSE)
#> No digestion column: digestion diagnostics disabled.
if (FALSE) { # \dontrun{
dv_deploy(prep, file = "dietview_dashboard.html", dir = tempdir())
} # }
```
