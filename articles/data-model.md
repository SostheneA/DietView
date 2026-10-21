# The DietView data model and input contract

This vignette shows how to describe your own table to DietView. DietView
needs one thing from your data: one row per prey record, that is, one
prey taxon found in one stomach. Taxonomy, tables, figures and
dashboards are all built from that table and from a specification that
says which column is which.

``` r

library(DietView)
```

## One row per prey record

Column names are free. You do not rename your data; you declare once
which column plays which role. Here is the example table that ships with
the package. It is invented: 24 prey records from 11 stomachs of three
predators.

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
#>  $ size_bin                    : chr  "[40, 50)" "[40, 50)" "[40, 50)" "[50, 60)" ...
#>  $ region                      : chr  "Northumberland" "Northumberland" "Northumberland" "Northumberland" ...
```

The table has no `kingdom` to `species` columns. DietView adds them when
you attach a taxonomy (see the vignette on WoRMS).

## Declaring roles with `dv_spec()`

``` r

spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",       # WoRMS AphiaID, used first when present
  prey_name      = "verified_name",  # scientific name, used when there is no ID
  weight         = "prey_weight",
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)
```

The roles and what they do:

| Role | Required | Purpose |
|----|----|----|
| `predator` | yes | the predator of each record; a grouping and display label |
| `stomach` | yes | the stomach each record came from; must be unique across the whole table, because stomach counts count distinct identifiers |
| `prey_id` / `prey_name` | at least one | prey keys used to attach the taxonomy |
| `weight` | no | the weight share (%W) |
| `count` | no | number of individuals per record, for the numerical share (%N). Records without a count contribute nothing to %N, so unidentified material usually disappears from that view |
| `digestion` | no | enables the digestion diagnostic |
| `covariates` | no | columns you want to compare diets across |
| `predator_latin` | no | used to look up identification photos |

## Checking a table against a specification

[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
stops if a declared column is missing, if there is no prey key column,
or if a weight is negative. It warns about records with no prey key,
weights that are not numbers and stomach IDs shared between predators,
and it ends with a one-line description of the sample. It reports
problems and never changes your data. It returns the data invisibly, so
you can use it in a pipeline.

``` r

invisible(dv_validate(dat, spec))
#> 24 records from 11 stomachs of 3 predator(s); 1 stomach(s) hold a single record; 0 record(s) lack a weight.
```

## Mapping your own survey

To use DietView on another table, write a different
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
If your columns were `sp`, `stom`, `aphia`, `wt_g` and `yr`, you would
write:

``` r

spec <- dv_spec(
  predator = "sp", stomach = "stom", prey_id = "aphia",
  weight = "wt_g", covariates = "yr"
)
```

The later steps
([`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
[`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md),
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md))
read the column names from the specification, never from your code. The
article “Adapting DietView to your own survey” goes through the other
choices you make with a new table.
