# Comparing diets across periods, sizes and regions

Most diet questions are comparisons: before and after a change in the
ecosystem, small and large predators, one region and another. In
DietView a comparison starts with a covariate, a column you declare in
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
This article shows how to build covariates from years and lengths, how
to draw one sunburst per level so the panels can be compared, and how to
cross two covariates.

The example table is invented and small: 24 records, 12 in each period.
The panels below show how a comparison is laid out. They are not
evidence that the diet changed.

``` r

library(DietView)

dat <- read.csv(system.file("extdata", "dietview_example.csv", package = "DietView"),
                na.strings = c("NA", ""))
lin <- read.csv(system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
                na.strings = c("NA", ""))
```

## 1. Build covariates from years and lengths

[`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
cuts years into periods and
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
cuts lengths into bins:

``` r

dv_add_period(c(2004, 2006, 2010, 2018), breaks = c(2003, 2007, 2020))
#> [1] 2003-2007 2003-2007 2008-2020 2008-2020
#> Levels: 2003-2007 2008-2020
dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60))
#> [1] [0, 20)  [20, 30) [30, 40) [40, 60)
#> Levels: [0, 20) [20, 30) [30, 40) [40, 60)
```

Two details decide which bin a value falls in. A year equal to an inner
break belongs to the earlier period (2007 falls in the first period
above). A length equal to an inner break belongs to the bin that starts
there (30 cm falls in the 30 to 40 bin), and a length at or beyond the
last break gets no bin at all. Choose breaks that cover every value you
have:

``` r

range(dat$somatic_length_cm)
#> [1] 12 75
dat$size_bin <- dv_size_bins(dat$somatic_length_cm, breaks = c(0, 30, 40, 50, 60, 100))
table(dat$size_bin, useNA = "ifany")
#> 
#>   [0, 30)  [30, 40)  [40, 50)  [50, 60) [60, 100) 
#>        12         5         3         2         2
```

With `breaks = c(0, 40, 50, 60)` the 75 cm cod would have no size bin. A
record without a level is left out of that covariate’s panels in the
dashboard, and shown in a separate “NA” panel in the Shiny app, so check
the table above before you go on. This `NA` is a missing stratum; it has
nothing to do with the unidentified prey in the sunburst.

Then declare the covariates and prepare the data:

``` r

spec <- dv_spec(predator = "predator_species_common_name", stomach = "stomach_id",
                prey_id = "aphia_id", prey_name = "verified_name",
                weight = "prey_weight",
                covariates = c("period", "size_class", "size_bin", "region"))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin, verbose = FALSE)
```

## 2. One sunburst per period

Build one palette from all the records first, so that a taxon has the
same color in every panel:

``` r

pal <- dv_palette(unlist(lapply(prep$ranks, function(r) prep$data[[r]])))
```

Then build one tree per level and draw each with that palette:

``` r

d <- prep$data
periods <- sort(unique(d$period))
table(d$period)
#> 
#> 2004-2006 2018-2019 
#>        12        12
```

``` r

t1 <- dv_build_tree(d[d$period == periods[1], ], prep$ranks, weight_col = spec$weight)
dv_sunburst(t1, mode = "occurrence", colors = pal, title = paste("Period", periods[1]))
```

``` r

t2 <- dv_build_tree(d[d$period == periods[2], ], prep$ranks, weight_col = spec$weight)
dv_sunburst(t2, mode = "occurrence", colors = pal, title = paste("Period", periods[2]))
```

How to read two panels side by side: both start at the same angle and
list taxa in the same order, so you read them in the same direction. A
taxon does not always sit at the same angle, though. If it is absent
from one period, every wedge after it moves round to close the gap. Use
color, not position, to find a taxon in both panels, and the hover
labels to read its share.

To compare numbers rather than pictures, put the two rank tables side by
side:

``` r

cmp <- merge(dv_rank_table(t1, "Class")[, c("label", "pct_occ")],
             dv_rank_table(t2, "Class")[, c("label", "pct_occ")],
             by = "label", all = TRUE, suffixes = c("_p1", "_p2"))
cmp[is.na(cmp)] <- 0
cmp
#>          label pct_occ_p1 pct_occ_p2
#> 1     Bivalvia   8.333333   8.333333
#> 2     Copepoda  25.000000   8.333333
#> 3 Malacostraca  33.333333  58.333333
#> 4           NA   0.000000  16.666667
#> 5   Polychaeta  16.666667   0.000000
#> 6    Teleostei  16.666667   8.333333
```

Each column is a share of that period’s records, unidentified records
included, so both columns add up to 100. With 12 records per period, a
difference of one record is a difference of more than 8 percentage
points: treat every difference here as noise. On real data, decide in
advance how many stomachs a panel needs before you interpret it, and
report that number with the figure.

## 3. Crossing two covariates

Often the question is size within period: does the diet of large
predators differ between periods in the same way as that of small ones?
First count what each combination holds:

``` r

combos <- expand.grid(size = sort(unique(d$size_class)),
                      per  = sort(unique(d$period)),
                      stringsAsFactors = FALSE)
combos$n_records  <- mapply(function(s, p) sum(d$size_class == s & d$period == p),
                            combos$size, combos$per)
combos$n_stomachs <- mapply(function(s, p)
  length(unique(d$stomach_id[d$size_class == s & d$period == p])),
  combos$size, combos$per)
combos
#>       size       per n_records n_stomachs
#> 1    adult 2004-2006         9          4
#> 2 juvenile 2004-2006         3          2
#> 3    adult 2018-2019        10          4
#> 4 juvenile 2018-2019         2          1
```

Crossing divides the sample quickly: here the juvenile cells hold two or
three records each. Draw a cell only when it holds enough stomachs to be
worth reading:

``` r

sub <- d[d$size_class == "adult" & d$period == periods[1], ]
tc  <- dv_build_tree(sub, prep$ranks, weight_col = spec$weight)
dv_sunburst(tc, mode = "occurrence", colors = pal,
            title = paste("adult,", periods[1]))
```

The Shiny app does the same interactively: choose a covariate under
**Facet by covariate** and a second one under **Cross with**, and it
draws one panel per combination (`run_dietview(prep)`).

## 4. All strata in one file

[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
writes every comparison into one HTML file: `strata` gives each
covariate its own row of sunbursts, and `cross` adds crossed rows.
`cross = list(c(inner, outer))` reads “inner within outer”: one row per
level of `outer`, one sunburst per level of `inner` in that row.

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet_by_strata.html"),
              strata = c("period", "size_class", "size_bin"),
              cross  = list(c("size_bin", "period"),     # length bins within periods
                            c("size_class", "period")))  # size classes within periods
```

By default the build stays offline; see the species-cards article for
predator photos from iNaturalist, with their authors and licenses.
