# Exploring and aggregating diet data

This article covers the functions you use before drawing a diet: a few
descriptive summaries, a prey accumulation curve, the classical
frequency of occurrence, aggregation of rare prey to a stated threshold,
and export of a stomach-by-prey matrix. It runs on the public ICES
stomach data that ship with the package (ICES Stomach Content Database,
ICES, Copenhagen; extract distributed with the R package stomachr,
Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)),
prepared with the standard set-up used throughout the documentation.

``` r

library(DietView)

# drop non-food items and nematodes (mostly parasites, not prey)
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]

spec <- dv_spec(
  predator       = "predator_common",
  predator_latin = "predator_latin",
  stomach        = "stomach_id",
  prey_id        = "prey_aphia_id",
  prey_name      = "prey_name",
  weight         = "prey_weight_g",
  count          = "prey_count",
  digestion      = "digestion_label",
  covariates     = c("region", "year", "quarter")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
```

## 1. Describe the sample first

[`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
gives, for each predator, the number of stomachs and prey records, the
number of distinct prey taxa and the mean number of records per stomach.
Pass `by` to break it down by a covariate.

``` r

s <- dv_summary(prep)
s$total_weight <- round(s$total_weight)
s
#>            predator_common n_stomachs n_records n_taxa records_per_stomach
#> 1        Atlantic mackerel       1048      1593     10                1.52
#> 2             Atlantic cod        991      2304    144                2.32
#> 3                  Whiting        892      1605    101                1.80
#> 4          European plaice        729      1890     69                2.59
#> 5  Atlantic horse mackerel        135       245     24                1.81
#> 6            European hake        106       154     23                1.45
#> 7              Tub gurnard         90       187     37                2.08
#> 8             Thorny skate         48       184     27                3.83
#> 9                   Turbot         47        87     21                1.85
#> 10                   Brill         26        51     15                1.96
#> 11                  Angler         20        37     11                1.85
#> 12            Grey gurnard         20        30      8                1.50
#> 13             Spotted ray         15        51     10                3.40
#> 14              Cuckoo ray         13        37      8                2.85
#> 15           Thornback ray         12        28      8                2.33
#> 16           Spiny dogfish         11        15      7                1.36
#> 17                 Pollack          9        17      8                1.89
#> 18                    Ling          4         4      4                1.00
#> 19        Atlantic halibut          2         4      3                2.00
#> 20              Blonde ray          2         3      2                1.50
#> 21           Smooth-hounds          1         1      1                1.00
#> 22     Starry smooth-hound          1         3      2                3.00
#>    total_weight
#> 1          2064
#> 2         10227
#> 3          2028
#> 4          1021
#> 5           105
#> 6          1863
#> 7           711
#> 8           117
#> 9           766
#> 10          201
#> 11         1699
#> 12           20
#> 13           41
#> 14           32
#> 15          146
#> 16          102
#> 17          367
#> 18          226
#> 19          126
#> 20            1
#> 21           12
#> 22           24
```

The sample is very uneven: four predators (mackerel, cod, whiting and
plaice) hold 87% of the stomachs, and 10 of the 22 predators have fewer
than 20 stomachs. Read every statistic for those last ones as anecdote.

By default a taxon is the finest name reached, so “Decapoda” and
*Crangon crangon* count as two even though the second is a decapod. Read
that count as the number of distinct prey names, not as species
richness. Pass `rank` to count taxa at one stated rank, unidentified
records excluded:

``` r

head(dv_summary(prep, rank = "family")[, c("predator_common", "n_stomachs", "n_taxa")], 4)
#>     predator_common n_stomachs n_taxa
#> 1 Atlantic mackerel       1048      3
#> 2      Atlantic cod        991     67
#> 3           Whiting        892     39
#> 4   European plaice        729     37
```

Cod has 144 distinct prey names but 67 families. Mackerel, with the
largest number of stomachs, has only 10 prey names: most of its records
are “Unidentified material”, “Crustacea”, “Pisces” or sandeels
(Ammodytidae).

A table of prey records holds only stomachs that contained something, so
it cannot give the share of empty stomachs. That has to come from the
full list of stomachs examined, which the package ships as
`ices_stomachs`:

``` r

# % of sampled stomachs flagged empty
e <- tapply(ices_stomachs$stomach_empty %in% 1, ices_stomachs$predator_common, mean)
round(100 * e[c("Atlantic cod", "Atlantic mackerel", "European plaice", "Whiting")], 1)
#>      Atlantic cod Atlantic mackerel   European plaice           Whiting 
#>               3.3               0.3              30.1              12.3
```

## 2. Is the diet adequately sampled?

[`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
builds the cumulative prey curve: the number of prey taxa found against
the number of stomachs examined, averaged over random orders of the
stomachs. A curve that levels off means more stomachs would add few new
taxa; a curve still rising means the sample is not yet enough.

Count taxa at one stated rank. With the finest names, a curve rises each
time a new coarse name (“Crustacea”, “Decapoda”) appears next to the
species already seen, and the rise grows with digestion. Here, family:

``` r

four <- c("Atlantic cod", "Atlantic mackerel", "European plaice", "Whiting")
acc <- dv_prey_accumulation(prep, by = spec$predator, rank = "family",
                            permutations = 50, seed = 1)
acc <- acc[acc$predator_common %in% four, ]

plot(NA, xlim = c(0, max(acc$n_stomachs)), ylim = c(0, max(acc$mean_richness)),
     xlab = "Stomachs examined", ylab = "Cumulative prey families",
     main = "Prey accumulation at family rank")
cols <- c("#1f77b4", "#ff7f0e", "#2ca02c", "#d62728")
for (i in seq_along(four)) {
  a <- acc[acc$predator_common == four[i], ]
  lines(a$n_stomachs, a$mean_richness, col = cols[i], lwd = 2)
}
legend("topleft", legend = four, col = cols, lwd = 2, bty = "n")
```

![](exploration_files/figure-html/accumulation-1.png)

``` r

# families gained over the last 100 stomachs of each curve
sapply(split(acc, acc$predator_common), function(a) {
  n <- nrow(a)
  round(a$mean_richness[n] - a$mean_richness[n - 100], 1)
})
#>      Atlantic cod Atlantic mackerel   European plaice           Whiting 
#>               1.9               0.0               2.0               1.2
```

The cod, whiting and plaice curves are still rising slowly at the full
sample size: the last 100 stomachs add one or two families each. The
mackerel curve is flat, but not because the mackerel diet is well
sampled: almost nothing in its stomachs was identified to family. A flat
curve says that more stomachs, read the same way, would add few new
families; it says nothing about what better identification would add.

Keep `permutations` low while exploring and raise it for a figure. The
seed is used for that call only.

## 3. Frequency of occurrence (%FO)

[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
gives `pct_occ`, the share of prey records. Shares of records add up
across the ranks, which is what lets them be drawn as a sunburst, but
they are not the frequency of occurrence of the diet literature.
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
computes %FO: the share of non-empty stomachs that contain each taxon,
computed separately at each rank, as recommended for comparison between
studies (Buckland et al., 2017).

``` r

fo <- dv_fo_table(prep, rank = "class", by = spec$predator)
head(fo[fo$predator_common == "Atlantic cod", ], 6)
#>    predator_common  rank        taxon n_stomachs n_total pct_fo
#> 11    Atlantic cod class Malacostraca        618     991  62.36
#> 12    Atlantic cod class    Teleostei        332     991  33.50
#> 13    Atlantic cod class           NA        323     991  32.59
#> 14    Atlantic cod class   Polychaeta        136     991  13.72
#> 15    Atlantic cod class  Ophiuroidea         49     991   4.94
#> 16    Atlantic cod class     Bivalvia         28     991   2.83
```

Crustaceans (Malacostraca) occur in 62.36% of the non-empty cod stomachs
and fish (Teleostei) in 33.5%. The same classes are 43.4% and 27.1% of
the cod’s prey records. The two quantities answer different questions
(how many fish ate it, and how much of the recorded material it is) and
should be reported under their own names. The column `n_total` is the
number of non-empty stomachs in the group: the denominator of %FO.

%FO does not add up across ranks: a parent’s %FO is computed from the
stomachs that contain it, not summed from its children, and the `NA` row
(stomachs holding at least one record not identified to class) overlaps
the others. Leave `rank = NULL` to stack every rank.

## 4. Aggregating rare prey to a stated threshold

By default DietView keeps each record at the deepest rank it reached. To
make the reporting resolution a stated choice,
[`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
moves prey found in fewer than `threshold` stomachs up to their parent,
and repeats up the hierarchy until every category it reports occurs in
at least `threshold` stomachs.

### Choosing the threshold

The threshold is a judgement, so look at what it costs before you fix
it.
[`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.md)
runs the aggregation for several values and reports the number of
categories left and the share of records whose category is coarser than
species:

``` r

sw <- dv_threshold_sweep(prep, thresholds = c(5, 10, 20, 30, 50, 100))
sw
#>   threshold n_categories pct_coarser
#> 1         5          110       83.28
#> 2        10           81       84.29
#> 3        20           57       86.17
#> 4        30           42       88.19
#> 5        50           32       89.60
#> 6       100           23       94.19
```

The share of records above species is high whatever the threshold
(83.28% at 5 stomachs), because most records were never identified to
species. Raising the threshold from 5 to 20 stomachs halves the number
of categories (110 to 57) and moves only 2.9 more percent of the records
to a coarser rank; beyond 50 the categories become broad groups. We use
20 stomachs here: about 0.5% of the 4,222 stomachs, enough for a
category to be compared between the main predators, and a point where
the sweep has removed most of the rare names at little cost. State the
value and the reason in your methods; a different question (a
per-predator description, a rare-prey study) would justify a different
one.

### The aggregated data

``` r

agg <- dv_aggregate_threshold(prep, threshold = 20)
attr(agg, "aggregation")$n_categories
#> [1] 57
head(sort(table(agg$data$prey_category), decreasing = TRUE), 12)
#> 
#>     Decapoda (other)     Chordata (other)   Arthropoda (other) 
#>                  798                  721                  664 
#>   Polychaeta (other)  Ophiuroidea (other)  Ammodytidae (other) 
#>                  498                  439                  364 
#>      Crangon crangon             Bivalvia    Amphipoda (other) 
#>                  326                  317                  249 
#>     Gobiidae (other) Merlangius merlangus         Aphia minuta 
#>                  188                  170                  154
table(agg$data$prey_rank, useNA = "ifany")
#> 
#>   class  family   genus kingdom   order  phylum species    <NA> 
#>    1522    1047     389      39    1310    1490    1180    1553
```

A category named after a taxon that also has retained descendants holds
only the records that stayed at that taxon, and its label ends in
“(other)”. “Decapoda (other)” holds the decapods that are not in a
retained family, genus or species of their own: the many records named
only “Brachyura”, “Caridea” or “Decapoda”, and rare decapods merged into
them. Named species such as *Crangon crangon* (brown shrimp),
*Merlangius merlangus* (whiting eaten by other fish) and *Aphia minuta*
(transparent goby) are frequent enough to stay on their own. The 1,553
records with no prey placement at all stay unidentified (`NA`).

The result is a `dietview_prep` again: ranks finer than the rank each
record settled at are set to `NA`, so it goes straight back into the
usual functions, and the sunburst then has no category rarer than the
threshold.

``` r

tree_agg <- dv_build_tree(agg$data[agg$data$predator_common == "Atlantic cod", ],
                          agg$ranks, weight_col = spec$weight)
dv_sunburst(tree_agg, mode = "occurrence", colors = dv_palette_tree(tree_agg),
            title = "Atlantic cod, prey aggregated to 20 stomachs",
            subtitle = "share of prey records")
```

Two arguments give three ways of counting:

``` r

dv_aggregate_threshold(prep, 20)                      # all predators pooled
dv_aggregate_threshold(prep, 20, min_predators = 2)   # pooled, and in at least 2 predators
dv_aggregate_threshold(prep, 20, scope = "per_predator")
```

The per-predator scope counts stomachs within each predator, so a prey
must reach the threshold in one predator’s own stomachs. A prey found in
15 cod and 10 whiting stomachs keeps its category in the pooled tree but
is merged upward in both predator trees. That leaves fewer categories at
the same threshold:

``` r

dv_threshold_sweep(prep, thresholds = c(5, 10, 20, 30, 50), scope = "per_predator")
#>   threshold n_categories pct_coarser
#> 1         5           98       84.83
#> 2        10           74       86.81
#> 3        20           46       90.33
#> 4        30           31       93.93
#> 5        50           28       94.42
```

DietView stops at the aggregation. If you summarize a statistic across
several thresholds, do it in your own analysis.

## 5. Handing over to multivariate analysis

[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
turns the records into the stomach-by-prey matrix that ordination,
PERMANOVA and compositional regression expect. If you aggregated first,
it uses the `prey_category` column automatically. Pass `rank` to build
the matrix at one rank instead.

``` r

m <- dv_matrix(agg, currency = "weight")
dim(m)
#> [1] 4222   58
m[1:3, c("Crangon crangon", "Decapoda (other)", "Chordata (other)", "NA")]
#>         Crangon crangon Decapoda (other) Chordata (other) NA
#> S107497               0                0            1.394  0
#> S107498               0                0            1.505  0
#> S107499               0                0            0.000  0
```

One row per stomach (4,222), one column per category (58, the `NA`
column included), summed prey weight in each cell. The matrix is very
sparse: 97.2% of its cells are zero, which is typical of stomach data
and matters for the choice of distance in the analysis that follows.

`currency` is `"weight"` (summed weight), `"occurrence"` (number of
records) or `"fo"` (presence or absence in each unit). Use `unit` to sum
over something coarser than a stomach, such as a haul
(`unit = "haul_id"`). Use `include_na = FALSE` to drop the unidentified
column, and say in your methods that you did.

``` r

# DietView stops here; the analysis uses other packages
mm <- vegan::decostand(m[rowSums(m) > 0, ], "total")
d  <- vegan::vegdist(mm, "bray")
# vegan::adonis2(d ~ predator_common + region, data = stomach_covariates)
```

## Where this fits

These functions describe and aggregate. DietView does not test
hypotheses: diversity tests, PERMANOVA and dispersion analyses belong to
packages built for them, and
[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
is the step that hands your data over.

## References

Buckland, A., Baker, R., Loneragan, N., & Sheaves, M. (2017).
Standardising fish stomach content analysis: the importance of prey
condition. *Fisheries Research*, 196, 126–140.

ICES Stomach Content Database. ICES, Copenhagen.
<https://stomachdata.ices.dk>. Extract distributed with the R package
stomachr (Lindmark 2026, <https://github.com/maxlindmark/stomachr>).
