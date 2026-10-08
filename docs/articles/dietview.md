# Getting started with DietView

DietView takes a **plain long table of stomach-content records** — one
row per prey record — and produces taxonomically complete,
covariate-aware sunburst views of predator diet. This article walks the
whole pipeline on the bundled example, fully offline (no internet, no
`worrms`), using a lineage lookup table to attach taxonomy.

``` r

library(DietView)
```

## 1. The input contract

One row is **one prey record in one stomach**. Column names are free —
you map them to DietView’s roles once. The bundled base table carries no
`kingdom .. species` columns; DietView adds them.

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

## 2. Declare your columns with `dv_spec()`

Nothing is hard-coded. You describe the roles once and pass the
resulting spec to every other function.

``` r

spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",
  prey_name      = "verified_name",
  weight         = "prey_weight",
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)
```

[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
checks that every declared column exists and tells you which currencies
and diagnostics will be available.

``` r

invisible(dv_validate(dat, spec))
```

## 3. Attach taxonomy

Two paths lead to the same prepared object. **Offline / reproducible**:
join a lineage lookup you supply.

``` r

lin <- read.csv(
  system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
  na.strings = c("NA", "")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin)
prep
#> <dietview_prep>
#>   records   : 24 
#>   predators : 3 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: period, size_class, size_bin, region
```

**Live from WoRMS** (needs the `worrms` package and internet; results
are cached to disk). Fuzzy matches and unresolved prey are flagged,
never silent — review them with
[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md).

``` r

prep <- dv_prepare(dat, spec, taxonomy = "worms")
dv_taxonomy_report(prep)          # audit fuzzy + unresolved matches
```

## 4. Within-rank importance

[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
aggregates the records into a multi-rank tree. Each rank sums to 100 %,
the explicit `NA` category included, in both occurrence and weight.

``` r

tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
dv_rank_table(tree, "Class")
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca          7        11 45.833333 39.7600 51.504725584
#> 9      Copepoda          2         4 16.666667  0.0048  0.006217874
#> 11    Teleostei          3         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta          1         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia          1         2  8.333333  0.0290  0.037566324
#> 13           NA          1         2  8.333333  1.6000  2.072624772
```

The within-rank shares are a genuine partition:

``` r

round(sum(dv_rank_table(tree, "Class")$pct_occ), 3)  # 100
#> [1] 100
```

## 5. Sunbursts

The multi-rank sunburst reads coarse (centre) to fine (edge).
Orientation is fixed so covariate cells stay directly comparable;
unidentified prey (`NA`) is white.

``` r

dv_sunburst(tree, mode = "occurrence", title = "All predators",
            subtitle = "occurrence share within each rank")
```

The same tree in the weight currency:

``` r

dv_sunburst(tree, mode = "weight", title = "All predators",
            subtitle = "weight share within each rank")
```

## 6. The digestion identification bias

As digestion advances, the finest resolved rank shifts toward coarse
ranks and “Unresolved”.
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
makes that bias explicit, optionally split by a covariate.

``` r

head(dv_digestion_diagnostic(prep, by = "period"), 10)
#>    digestion        by finest_rank n_records  weight p_records    p_weight
#> 1          1 2004-2006     Species         1  0.0020 100.00000 100.0000000
#> 2          1 2018-2019     Species         1  9.0000 100.00000 100.0000000
#> 3          2 2004-2006       Class         3  0.5128  60.00000   3.7670428
#> 4          2 2004-2006     Species         2 13.1000  40.00000  96.2329572
#> 5          2 2018-2019       Order         2  0.1100  50.00000   0.4963899
#> 6          2 2018-2019     Species         2 22.0500  50.00000  99.5036101
#> 7          3 2004-2006       Class         2  0.2010  50.00000   3.7563072
#> 8          3 2004-2006      Family         1  0.0500  25.00000   0.9344048
#> 9          3 2004-2006     Species         1  5.1000  25.00000  95.3092880
#> 10         3 2018-2019       Order         2  0.4500  66.66667   2.9126214
```

## 7. Covariate helpers

Derive a period from year, or per-group length bins, and feed them back
as covariates.

``` r

dv_add_period(c(2004, 2009, 2018), breaks = c(2003, 2007, 2020))
#> [1] 2003-2007 2007-2020 2007-2020
#> Levels: 2003-2007 2007-2020
dv_size_bins(c(18, 32, 47), breaks = c(0, 20, 30, 40, 60))
#> [1] [0-20[  [30-40[ [40-60[
#> Levels: [0-20[ [20-30[ [30-40[ [40-60[
```

## 8. Ship it

A self-contained HTML dashboard (searchable predator cards + one tab per
predator), or the interactive Shiny explorer.

``` r

dv_deploy(prep, file = "dietview_dashboard.html", dir = "outputs",
          strata = c("period", "size_class", "size_bin"),
          cross  = list(c("size_bin", "period")),
          length_col = "somatic_length_cm")

run_dietview(prep)
```

See [Building a self-contained diet
dashboard](https://sosthenea.github.io/DietView/articles/dashboard.md)
for the dashboard options in detail, and [Resolving prey taxonomy with
WoRMS](https://sosthenea.github.io/DietView/articles/taxonomy-worms.md)
for the online taxonomy path.
