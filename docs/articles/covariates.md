# Comparing diets across periods, sizes and regions

Most diet questions are comparisons: before and after a change in the
ecosystem, small and large predators, one region and another. In
DietView a comparison starts with a covariate, a column you declare in
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
This article shows how to build covariates from years and lengths, how
to count what each level holds before reading it, how to draw one
sunburst per level so the panels can be compared, and how to cross two
covariates.

It uses the public ICES stomach data that ship with the package (ICES
Stomach Content Database, ICES, Copenhagen; extract distributed with the
R package stomachr, Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)),
restricted to the four predators with the most prey records. The data
were not collected to answer any of the comparisons below: the strata
are uneven, and part of the article is about seeing that before drawing
conclusions.

``` r

library(DietView)

# drop non-food items and nematodes (mostly parasites, not prey)
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]

four <- c("Atlantic cod", "Atlantic mackerel", "European plaice", "Whiting")
dat  <- dat[dat$predator_common %in% four, ]
table(dat$predator_common)
#> 
#>      Atlantic cod Atlantic mackerel   European plaice           Whiting 
#>              2304              1593              1890              1605
```

## 1. Build covariates from years and lengths

`region`, `year` and `quarter` are already columns of the data. Two more
are built here: a period from the year and a length class from the
predator’s length.

### Periods

[`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
cuts years into periods. Look at the years first:

``` r

table(dat$predator_common, dat$year)
#>                    
#>                     2020 2021 2022 2023 2024
#>   Atlantic cod         0   13  586 1161  544
#>   Atlantic mackerel    0    0 1593    0    0
#>   European plaice      0    0    0    0 1890
#>   Whiting             17    0 1154  434    0
```

Only cod spans several years. Mackerel were sampled in 2022 only and
plaice in 2024 only, so a period comparison is a cod (and partly
whiting) question. We compare 2022 with 2023-2024. The obvious call,
`dv_add_period(year, breaks = c(2021, 2022, 2024))`, would put 2021 into
the first period with 2022, because the first period includes its lower
break. Make the choice explicit instead:

``` r

dat$period <- dv_add_period(dat$year, breaks = c(2021.5, 2022, 2024),
                            labels = c("2022", "2023-2024"))
table(dat$year, dat$period, useNA = "ifany")
#>       
#>        2022 2023-2024 <NA>
#>   2020    0         0   17
#>   2021    0         0   13
#>   2022 3333         0    0
#>   2023    0      1595    0
#>   2024    0      2434    0
```

The 30 records from 2020 and 2021 now have no period (`NA`). They stay
in the data and in every other comparison; they are only left out of the
period panels. A year equal to an inner break belongs to the earlier
period, so 2022 falls in the first one.

### Length classes

[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
cuts lengths into bins. Predators differ in size, so give each its own
breaks:

``` r

sapply(split(dat$length_cm, dat$predator_common), range)
#>      Atlantic cod Atlantic mackerel European plaice Whiting
#> [1,]            6              17.7              11       9
#> [2,]          104              45.2              54      44
```

``` r

breaks <- list(
  "Atlantic cod"      = c(0, 20, 35, 50, 110),
  "Whiting"           = c(0, 20, 30, 50),
  "Atlantic mackerel" = c(15, 30, 35, 50),
  "European plaice"   = c(10, 20, 30, 60)
)
dat$size_bin <- NA_character_
for (p in names(breaks)) {
  i <- dat$predator_common == p
  dat$size_bin[i] <- as.character(dv_size_bins(dat$length_cm[i], breaks[[p]]))
}
table(dat$predator_common, dat$size_bin, useNA = "ifany")
#>                    
#>                     [0, 20) [10, 20) [15, 30) [20, 30) [20, 35) [30, 35)
#>   Atlantic cod          364        0        0        0      964        0
#>   Atlantic mackerel       0        0      602        0        0      414
#>   European plaice         0      359        0      955        0        0
#>   Whiting               503        0        0      855        0        0
#>                    
#>                     [30, 50) [30, 60) [35, 50) [50, 110)
#>   Atlantic cod             0        0      544       432
#>   Atlantic mackerel        0        0      577         0
#>   European plaice          0      576        0         0
#>   Whiting                247        0        0         0
```

The breaks are a choice you make on biology and state in your methods.
Here the cod and whiting breaks bracket the lengths at which these
gadoids turn from crustaceans to fish; the mackerel and plaice breaks
split the juveniles from the larger adults. Each bin includes its lower
edge (`right = FALSE`), so a 20 cm cod is in `[20, 35)`. Every break
vector covers the whole range shown above; a length outside the breaks
would get no bin. Check the table for `NA` before you go on.

### Declare them

``` r

spec <- dv_spec(
  predator       = "predator_common",
  predator_latin = "predator_latin",
  stomach        = "stomach_id",
  prey_id        = "prey_aphia_id",
  prey_name      = "prey_name",
  weight         = "prey_weight_g",
  count          = "prey_count",
  digestion      = "digestion_label",
  covariates     = c("region", "year", "quarter", "period", "size_bin")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
```

## 2. Count what each level holds

A level is worth reading only if it holds enough stomachs. Count
stomachs, not records: records within a stomach are not independent.

``` r

n_stom <- function(d, v) {
  tapply(d$stomach_id, list(d$predator_common, d[[v]]),
         function(z) length(unique(z)))
}
d <- prep$data
n_stom(d, "region")
#>                   Baltic Sea North Sea Skagerrak-Kattegat
#> Atlantic cod             198       731                 62
#> Atlantic mackerel         NA       948                100
#> European plaice           38       429                262
#> Whiting                  167       650                 75
n_stom(d, "quarter")
#>                     1    2   3   4
#> Atlantic cod      570   NA  97 324
#> Atlantic mackerel  NA 1048  NA  NA
#> European plaice   168   NA 561  NA
#> Whiting           551   NA 276  65
n_stom(d, "period")
#>                   2022 2023-2024
#> Atlantic cod       223       764
#> Atlantic mackerel 1048        NA
#> European plaice     NA       729
#> Whiting            625       254
```

`dv_summary(prep, by = "region")` gives the same counts with the number
of records and prey taxa. The empty cells (`NA`) are combinations that
were never sampled: no mackerel from the Baltic, no plaice in quarters 2
or 4. A comparison across a covariate is possible only for the predators
that occur in more than one of its levels.

## 3. One palette for every panel

Build the colors once, from the tree of all records, so that a taxon has
the same color in every panel. With several hundred prey taxa,
[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
would have to reuse its 20 colors many times;
[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
gives one hue per phylum and lighter tints to the taxa below it:

``` r

tree_all <- dv_tree(prep)
pal <- dv_palette_tree(tree_all)
length(pal)
#> [1] 653
```

The palette is keyed by node, so it works for any tree built from a
subset of these records.

## 4. Cod in 2022 and in 2023-2024

``` r

cod <- d[d$predator_common == "Atlantic cod", ]

t22 <- dv_build_tree(cod[cod$period %in% "2022", ], prep$ranks,
                     weight_col = spec$weight)
t34 <- dv_build_tree(cod[cod$period %in% "2023-2024", ], prep$ranks,
                     weight_col = spec$weight)
```

``` r

dv_sunburst(t22, mode = "weight", colors = pal, title = "Atlantic cod, 2022",
            subtitle = "share of prey weight")
```

``` r

dv_sunburst(t34, mode = "weight", colors = pal, title = "Atlantic cod, 2023-2024",
            subtitle = "share of prey weight")
```

How to read two panels side by side: both start at the same angle and
list taxa in the same order, so you read them in the same direction. A
taxon does not always sit at the same angle, though. If it is absent
from one period, every wedge after it moves round to close the gap. Use
color, not position, to find a taxon in both panels, and the hover
labels to read its share.

To compare numbers rather than pictures, put the two rank tables side by
side. Each column is a share of that period’s records (or weight),
unidentified records included, so each column adds up to 100:

``` r

side_by_side <- function(ta, tb, names, rank = "Class") {
  a <- dv_rank_table(ta, rank)
  b <- dv_rank_table(tb, rank)
  a <- a[a$label != "NA", c("label", "pct_occ", "pct_w")]
  b <- b[b$label != "NA", c("label", "pct_occ", "pct_w")]
  m <- merge(a, b, by = "label", all = TRUE, suffixes = paste0("_", names))
  m[is.na(m)] <- 0
  m[, -1] <- round(m[, -1], 1)
  m[order(-m[[2]]), ][1:5, ]
}
side_by_side(t22, t34, c("2022", "2023_24"))
#>          label pct_occ_2022 pct_w_2022 pct_occ_2023_24 pct_w_2023_24
#> 5 Malacostraca         57.7       68.6            38.4          18.1
#> 9    Teleostei         19.5       22.4            29.6          73.2
#> 8   Polychaeta          8.2        4.4             5.6           3.7
#> 7  Ophiuroidea          4.8        1.9             1.3           0.1
#> 1     Bivalvia          2.0        0.1             1.0           0.1
```

By weight, crustaceans fall from 68.6% of the cod diet in 2022 to 18.1%
in 2023-2024, and fish rise from 22.4% to 73.2%. Before calling this a
change in time, look at what else differs between the two periods:

``` r

n_stom(cod, "period")
#>              2022 2023-2024
#> Atlantic cod  223       764
tapply(cod$stomach_id, list(cod$region, cod$period), function(z) length(unique(z)))
#>                    2022 2023-2024
#> Baltic Sea           NA       198
#> North Sea           223       504
#> Skagerrak-Kattegat   NA        62
tapply(cod$stomach_id, list(cod$size_bin, cod$period), function(z) length(unique(z)))
#>           2022 2023-2024
#> [0, 20)     89       119
#> [20, 35)    73       375
#> [35, 50)    43       171
#> [50, 110)   18        99
```

All the 2022 cod come from the North Sea, while 2023-2024 adds the
Baltic and the Skagerrak-Kattegat; and the 2022 sample has
proportionally more small cod. The two periods differ in region and in
predator size as much as in time, so the difference in the panels cannot
be attributed to the period alone. This is the usual situation with
survey data assembled after the fact: read the sampling design off the
counts before you read the diet off the panels.

## 5. Cod by length class and by region

Length gives a cleaner contrast, because it varies within every region
and period. A small helper puts the stomach count next to the share of
fish (Teleostei) in each level:

``` r

fish_by <- function(x, v) {
  trees <- lapply(split(x, x[[v]]), function(s)
    dv_build_tree(s, prep$ranks, weight_col = spec$weight))
  out <- t(sapply(trees, function(t) {
    r <- dv_rank_table(t, "Class")
    c(fish_records_pct = round(sum(r$pct_occ[r$label == "Teleostei"]), 1),
      fish_weight_pct  = round(sum(r$pct_w[r$label == "Teleostei"]), 1))
  }))
  cbind(stomachs = n_stom(x, v)[1, rownames(out)], out)
}
by_size <- lapply(split(cod, cod$size_bin), function(x)
  dv_build_tree(x, prep$ranks, weight_col = spec$weight))

fish_share <- fish_by(cod, "size_bin")
fish_share
#>           stomachs fish_records_pct fish_weight_pct
#> [0, 20)        208             14.0            16.3
#> [20, 35)       450             18.8            31.5
#> [35, 50)       215             32.2            56.6
#> [50, 110)      118             50.2            79.7
```

The share of fish in the cod diet rises steadily with cod length, from
16.3% of the prey weight below 20 cm to 79.7% above 50 cm. The two ends
of the size range, with the same palette:

``` r

dv_sunburst(by_size[["[0, 20)"]], mode = "weight", colors = pal,
            title = "Atlantic cod, under 20 cm", subtitle = "share of prey weight")
```

``` r

dv_sunburst(by_size[["[50, 110)"]], mode = "weight", colors = pal,
            title = "Atlantic cod, 50 cm and over", subtitle = "share of prey weight")
```

The same lines work for any of the four predators; only the breaks
differ.

By region:

``` r

fish_by(cod, "region")
#>                    stomachs fish_records_pct fish_weight_pct
#> Baltic Sea              198             25.8            71.5
#> North Sea               731             27.4            68.8
#> Skagerrak-Kattegat       62             26.7            61.8
```

At class level the regions are close. Fish make up 71.5% of the cod prey
weight in the Baltic Sea, 68.8% in the North Sea and 61.8% in the
Skagerrak-Kattegat, where only 62 stomachs were sampled, all in one
year. Region, like period, is entangled with the other covariates: the
Baltic and Skagerrak-Kattegat cod were all caught in 2023-2024, and
their length distributions differ from the North Sea one. A table of
stomachs by region and length class (`n_stom()` on a crossed variable,
or the crossed panels below) is the first thing to look at before
interpreting any of these differences.

## 6. Crossing two covariates

Often the question is one covariate within another: does the diet of
large cod differ between periods in the same way as that of small ones?
First count what each combination holds:

``` r

cells <- tapply(cod$stomach_id, list(cod$size_bin, cod$period),
                function(z) length(unique(z)))
cells
#>           2022 2023-2024
#> [0, 20)     89       119
#> [20, 35)    73       375
#> [35, 50)    43       171
#> [50, 110)   18        99
```

Crossing divides the sample quickly. With 2291 cod records split into
eight cells, the largest cod of 2022 come from only 18 stomachs. Decide
in advance how many stomachs a cell needs before you interpret it, and
report that number with the figure. With a minimum of 30 stomachs, for
example, the cells to read are:

``` r

which(cells >= 30, arr.ind = TRUE)
#>           row col
#> [0, 20)     1   1
#> [20, 35)    2   1
#> [35, 50)    3   1
#> [0, 20)     1   2
#> [20, 35)    2   2
#> [35, 50)    3   2
#> [50, 110)   4   2
```

Draw a cell only when it passes:

``` r

sub <- cod[cod$size_bin == "[20, 35)" & cod$period %in% "2023-2024", ]
tc  <- dv_build_tree(sub, prep$ranks, weight_col = spec$weight)
dv_sunburst(tc, mode = "occurrence", colors = pal,
            title = "Atlantic cod, 20-35 cm, 2023-2024",
            subtitle = paste(length(unique(sub$stomach_id)), "stomachs; share of prey records"))
```

The Shiny app does the same interactively: choose a covariate under
**Facet by covariate** and a second one under **Cross with**, and it
draws one panel per combination (`run_dietview(prep)`).

## 7. A missing level is not an unidentified prey

Two kinds of `NA` appear in this article, and they mean different
things.

A covariate `NA` is a record that belongs to no level of the covariate:
here the 30 records from 2020 and 2021, which have no period. They are
not in any period panel. The dashboard leaves such records out of that
covariate’s row of panels, and the Shiny app shows them in a separate
“NA” panel, so you can see what was set aside.

A taxonomic `NA` is a prey record not identified to a rank: a white
wedge inside every panel, kept so that each ring still adds up to 100%.
It has nothing to do with the covariates:

``` r

c(period_na_records    = sum(is.na(d$period)),
  class_na_records_cod = sum(is.na(cod$class)))
#>    period_na_records class_na_records_cod 
#>                   30                  424
```

Report the first as a sample size (“13 cod records from 2021 were not
assigned a period”) and the second as an identification share (“18.4% of
the cod prey records were not identified to class”).

## 8. All strata in one file

[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
writes every comparison into one HTML file: `strata` gives each
covariate its own row of sunbursts, and `cross` adds crossed rows.
`cross = list(c(inner, outer))` reads “inner within outer”: one row per
level of `outer`, one sunburst per level of `inner` in that row.

``` r

dv_build_html(prep, output = file.path(tempdir(), "ices_by_strata.html"),
              strata = c("region", "quarter", "period", "size_bin"),
              cross  = list(c("size_bin", "period"),    # length classes within periods
                            c("size_bin", "region")),   # length classes within regions
              length_col = "length_cm")
```

The dashboard draws every cell that holds records, whatever its size,
and shows the number of stomachs in each. The small-cell rule is yours
to apply when you read it. By default the build stays offline; see the
species-cards article for predator photos from iNaturalist, with their
authors and licenses.
