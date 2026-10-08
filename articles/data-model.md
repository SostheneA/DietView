# The DietView data model and input contract

DietView is built on a single, deliberately simple contract: **one row
is one prey record in one stomach**. Everything else — taxonomy,
metrics, figures, dashboards — is derived from that. This article
explains the contract, the role system, and how to map *any* survey onto
it.

``` r

library(DietView)
```

## One row per prey record

Column names are free. You never rename your data; instead you declare,
once, which column plays which **role**. Here is the bundled base table:

``` r

dat <- read.csv(
  system.file("extdata", "dietview_example.csv", package = "DietView"),
  na.strings = c("NA", "")
)
str(dat)
#> 'data.frame':    24 obs. of  14 variables:
#>  $ predator_species_common_name: chr  "Atlantic cod" "Atlantic cod" "Atlantic cod" "Atlantic cod" ...
#>  $ predator_species_latin_name : chr  "Gadus morhua" "Gadus morhua" "Gadus morhua" "Gadus morhua" ...
#>  $ stomach_id                  : chr  "GM001" "GM001" "GM001" "GM002" ...
#>  $ aphia_id                    : int  107649 126752 1130 101107 293496 107649 1135 NA 127194 107323 ...
#>  $ verified_name               : chr  "Pandalus borealis" "Ammodytes dubius" "Decapoda" "Themisto libellula" ...
#>  $ prey_weight                 : num  12.3 5.1 2 0.8 8 9 0.3 1.5 22 15 ...
#>  $ number_of_prey              : int  3 2 1 20 1 2 5 NA 1 1 ...
#>  $ digestion_level_id          : int  2 3 4 2 4 1 3 5 2 3 ...
#>  $ period                      : chr  "2004-2006" "2004-2006" "2004-2006" "2004-2006" ...
#>  $ year                        : int  2005 2005 2005 2005 2005 2019 2019 2019 2019 2019 ...
#>  $ somatic_length_cm           : int  45 45 45 52 52 38 38 38 75 75 ...
#>  $ size_class                  : chr  "adult" "adult" "adult" "adult" ...
#>  $ size_bin                    : chr  "[40-50[" "[40-50[" "[40-50[" "[50-60[" ...
#>  $ region                      : chr  "Northumberland" "Northumberland" "Northumberland" "Northumberland" ...
```

Note what is *not* here: there are no `kingdom .. species` columns.
DietView adds those itself (see the taxonomy article).

## Declaring roles with `dv_spec()`

``` r

spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",       # WoRMS AphiaID (preferred key)
  prey_name      = "verified_name",  # fallback key
  weight         = "prey_weight",
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)
```

The roles and their meaning:

| Role | Required | Purpose |
|----|----|----|
| `predator` | yes | one predator per row |
| `stomach` | yes | unit of occurrence; drives stomach counts |
| `prey_id` / `prey_name` | one of them | prey key(s) for taxonomy |
| `weight` | no | the weight currency (`%W`) |
| `count` | no | per-record count for `%N` |
| `digestion` | no | enables the digestion diagnostic |
| `covariates` | no | any stratifiers |
| `predator_latin` | no | auto-fetch ID photos |

## Validating a table against a spec

[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
fails fast on hard errors (a missing required column, no prey key, an
absent covariate) and only warns on soft gaps (no weight → `%W` empty;
no digestion → diagnostic disabled). It returns the data invisibly, so
it composes in a pipeline.

``` r

invisible(dv_validate(dat, spec))
```

## Mapping your own survey

Because nothing is hard-coded, adapting DietView to a new dataset is
entirely a matter of writing a different
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
If your columns were, say, `sp`, `stom`, `aphia`, `wt_g`, and `yr`, you
would simply write:

``` r

spec <- dv_spec(
  predator = "sp", stomach = "stom", prey_id = "aphia",
  weight = "wt_g", covariates = "yr"
)
```

Everything downstream —
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
[`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md),
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
— reads the spec, never the literal names.
