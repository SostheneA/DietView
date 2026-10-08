# Covariate stratification: periods, size bins, and faceted diets

Any column you declare as a covariate can stratify the diet views. This
article covers the two helpers that build covariates and shows how to
compare diets across covariate levels with a fixed, comparable sunburst
orientation.

``` r

library(DietView)

dat <- read.csv(system.file("extdata", "dietview_example.csv", package = "DietView"),
                na.strings = c("NA", ""))
lin <- read.csv(system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
                na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name", stomach = "stomach_id",
                prey_id = "aphia_id", prey_name = "verified_name",
                weight = "prey_weight",
                covariates = c("period", "size_class", "size_bin", "region"))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin)
```

## Deriving covariates

Turn a year into a period, or a length into bins. Labels are auto-built.

``` r

dv_add_period(c(2004, 2006, 2010, 2018), breaks = c(2003, 2007, 2020))
#> [1] 2003-2007 2003-2007 2007-2020 2007-2020
#> Levels: 2003-2007 2007-2020
dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60))
#> [1] [0-20[  [20-30[ [30-40[ [40-60[
#> Levels: [0-20[ [20-30[ [30-40[ [40-60[
```

These feed straight back as covariate columns, e.g.:

``` r

dat$period   <- dv_add_period(dat$year, breaks = c(2003, 2007, 2020))
dat$size_bin <- dv_size_bins(dat$somatic_length_cm, breaks = c(0, 40, 50, 60))
```

## Comparing diets across a covariate

Because sunbursts are drawn with a fixed orientation (`sort = FALSE`,
fixed start angle), a taxon sits in the same place in every cell, so
cells are directly comparable. Here we compare periods by building a
tree per level:

``` r

d <- prep$data
periods <- sort(unique(d$period))
periods
#> [1] "2004-2006" "2018-2019"
```

``` r

t1 <- dv_build_tree(d[d$period == periods[1], ], prep$ranks, weight_col = spec$weight)
dv_sunburst(t1, mode = "occurrence", title = paste("Period", periods[1]))
```

``` r

t2 <- dv_build_tree(d[d$period == periods[2], ], prep$ranks, weight_col = spec$weight)
dv_sunburst(t2, mode = "occurrence", title = paste("Period", periods[2]))
```

Sharing one colour dictionary keeps colours consistent across the two
figures:

``` r

pal <- dv_palette(unlist(lapply(prep$ranks, function(r) prep$data[[r]])))
dv_sunburst(t1, mode = "occurrence", colors = pal, title = periods[1])
```

## Crossing two covariates

Often the interesting question is not “diet by period” or “diet by
size”, but **size within period**: does the ontogenetic shift look the
same in both periods? Build one tree per combination and compare the
cells.

``` r

d <- prep$data
combos <- expand.grid(size = sort(unique(d$size_class)),
                      per  = sort(unique(d$period)),
                      stringsAsFactors = FALSE)
combos$n_records <- mapply(function(s, p) sum(d$size_class == s & d$period == p),
                           combos$size, combos$per)
combos
#>       size       per n_records
#> 1    adult 2004-2006         9
#> 2 juvenile 2004-2006         3
#> 3    adult 2018-2019        10
#> 4 juvenile 2018-2019         2
```

``` r

sub <- d[d$size_class == combos$size[1] & d$period == combos$per[1], ]
tc  <- dv_build_tree(sub, prep$ranks, weight_col = spec$weight)
dv_sunburst(tc, mode = "occurrence", colors = pal,
            title = paste0(combos$size[1], " - ", combos$per[1]))
```

Reusing the same `pal` across every cell, and relying on the fixed
sunburst orientation, is what makes those cells comparable at a glance.

The interactive app does this for you: pick a covariate under **Facet by
covariate** and a second one under **Cross with**, and you get one panel
per combination (see
[`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)).

## Doing it all at once in the dashboard

The dashboard automates this: `strata` gives each covariate its own row
of sunbursts, and `cross` adds crossed rows (e.g. length bins within
periods). See the dashboard article.

`cross = list(c(inner, outer))` reads as “inner **by** outer”: one row
per level of `outer`, one sunburst per level of `inner` within it.

``` r

dv_deploy(prep, dir = "outputs",
          strata = c("period", "size_class", "size_bin"),
          cross  = list(c("size_bin", "period"),      # length bins by period
                        c("size_class", "period")))   # size class by period
```
