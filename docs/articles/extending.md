# Adapting DietView to your own survey

DietView is survey-agnostic. Adapting it is almost entirely a matter of
writing a different
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
This article collects the extension points.

``` r
library(DietView)
```

## 1. Map your columns

Nothing is hard-coded — declare roles once and every function follows:

``` r
spec <- dv_spec(predator = "sp", stomach = "stom", prey_id = "aphia",
                weight = "wt_g", covariates = c("yr", "zone"))
```

## 2. Go fully offline and reproducible

Freeze taxonomy into a lineage table and use `taxonomy = "table"` — no
`worrms`, no network, identical results every run:

``` r
lineage <- read.csv("my_curated_lineage.csv", na.strings = c("NA", ""))
prep <- dv_prepare(mydata, spec, taxonomy = "table", lineage = lineage)
```

## 3. Custom ranks

Display fewer or different ranks by passing your own `ranks`:

``` r
spec <- dv_spec(predator = "sp", stomach = "stom", prey_name = "prey",
                ranks = c("phylum", "class", "order", "family", "genus"))
```

## 4. Custom colours

Pass a named vector to `dv_sunburst(colors = )`, or build one with
[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md):

``` r
pal <- dv_palette(c("Teleostei", "Malacostraca", "Polychaeta", "NA"))
pal
#>    Teleostei Malacostraca   Polychaeta           NA 
#>    "#1f77b4"    "#aec7e8"    "#ff7f0e"    "#FFFFFF"
```

## 5. New covariates on the fly

Add columns, list them in `dv_spec(covariates = )`, and derive periods
and length bins with the helpers:

``` r
dv_add_period(c(2005, 2012, 2019), breaks = c(2003, 2010, 2020))
#> [1] 2003-2010 2010-2020 2010-2020
#> Levels: 2003-2010 2010-2020
dv_size_bins(c(22, 41, 58), breaks = c(0, 30, 45, 60))
#> [1] [0-30[  [30-45[ [45-60[
#> Levels: [0-30[ [30-45[ [45-60[
```

## 6. Non-marine or mixed taxa

WoRMS is marine-focused. For terrestrial or freshwater prey, supply your
own lineage table (step 2) rather than the `"worms"` path.
