# Complete case study: harbour seal scat DNA metabarcoding (Salish Sea)

## Question, source and sampling unit

**Research question.** Which prey groups are detected in harbour seal
scats, how does their *relative DNA signal* vary among groups of
samples, and how much taxonomic information is lost at finer ranks? This
is a descriptive worked analysis; it does not estimate ingested biomass
or prove a difference between seasons or laboratories.

We use the **real, packaged** `salish_seal_dna` data of Thomas et
al. (2022): 4,625 harbour seal (*Phoca vitulina*) scats from 52 Salish
Sea haul-outs, 2012–2018. Each row is a prey assignment **within one
scat**. The measured `diet_fraction` is an already calculated
within-scat DNA fraction, combining information from 16S and COI
markers. The frozen WoRMS taxonomy, `salish_seal_lineage`, avoids live
API lookups. The data source and CC0 status are documented in
[`?salish_seal_dna`](https://sosthenea.github.io/DietView/reference/salish_seal_dna.md).

**Unit:** one `sample_id` (scat). **Taxon key:** `prey_label`.
**Quantity:** `diet_fraction`, *not* prey grams. **Covariates:** site,
year, season and lab.

``` r

library(DietView)
dat <- salish_seal_dna
lin <- salish_seal_lineage
c(records = nrow(dat), scats = length(unique(dat$sample_id)),
  prey_labels = length(unique(dat$prey_label)), sites = length(unique(dat$site)))
#>     records       scats prey_labels       sites 
#>       11641        4625         117          52
head(dat[, c("sample_id", "prey_label", "diet_fraction", "season", "lab")])
#>   sample_id             prey_label diet_fraction season lab
#> 1  Pv12.001      Alosa sapidissima        0.9731 spring UBC
#> 2  Pv12.001        Clupea pallasii        0.0163 spring UBC
#> 3  Pv12.001  Metacarcinus magister        0.0106 spring UBC
#> 4  Pv12.002        Clupea pallasii        0.2859 spring UBC
#> 5  Pv12.002 Gasterosteus aculeatus        0.7141 spring UBC
#> 6  Pv12.003      Alosa sapidissima        0.0385 spring UBC
```

## Audit the input before analysis

A fraction should be finite, non-negative and, in these released data,
sum to approximately one **within each positive scat**. These checks are
diagnostic: they should not be used to silently remove unexpected
values.

``` r

stopifnot(!anyNA(dat$sample_id), !anyNA(dat$prey_label))
stopifnot(all(is.finite(dat$diet_fraction)), all(dat$diet_fraction >= 0))
scat_total <- tapply(dat$diet_fraction, dat$sample_id, sum)
summary(scat_total)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.9994  1.0000  1.0000  1.0000  1.0000  1.0005
max(abs(scat_total - 1))
#> [1] 6e-04
```

``` r

frame <- unique(dat[, c("sample_id", "site", "year", "season", "lab")])
stopifnot(!anyDuplicated(frame$sample_id))
print(table(frame$season, useNA = "ifany"))
#> 
#> winter spring summer autumn 
#>    288   1603   1622   1112
print(table(frame$lab, useNA = "ifany"))
#> 
#>  DFO  UBC WDFW 
#> 1173 1484 1968
```

**Interpretation.** `frame` counts scats, not prey records. Samples can
contain several prey detections. Without a complete list of *all scats
processed* we cannot calculate a survey-wide negative-detection or
extraction-failure rate: these released rows describe the samples
represented in the published table.

## Specify roles and freeze the taxonomy

`weight_type = "rra"` asks DietView to normalize the quantity within
each sample. Here the original fractions are already normalized;
applying this operation again is effectively idempotent (apart from
numeric rounding). For **raw** ASV read counts, the same argument first
performs the normalization; see the separate [ASV case
study](https://sosthenea.github.io/DietView/articles/case-study-asv-pipeline.md).

``` r

spec <- dv_spec(
  predator = "predator", stomach = "sample_id", prey_name = "prey_label",
  weight = "diet_fraction", weight_type = "rra", unit_label = "scat",
  covariates = c("site", "year", "season", "lab")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin,
                   verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 11641 
#>   scats     : 4625 
#>   predators : 1 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: site, year, season, lab 
#>   source    : table
c(raw_quantity = "diet_fraction", normalized_column = prep$spec$weight)
#>      raw_quantity normalized_column 
#>   "diet_fraction"             "rra"
```

``` r

normalized <- tapply(prep$data[[prep$spec$weight]], prep$data$sample_id, sum)
summary(normalized)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>       1       1       1       1       1       1
stopifnot(all(abs(normalized[scat_total > 0] - 1) < 1e-6))
```

The frozen classification retains the *shared* ranks for ambiguous
assignments such as two alternative rockfish species, instead of
choosing one arbitrarily. A prey label with more than one candidate is
not a precise species identification.

``` r

head(lin[lin$n_candidates > 1,
         c("prey_label", "family", "genus", "species", "n_candidates")])
#>                                                      prey_label         family
#> 11                   Artedius fenestralis OR Artedius lateralis       Cottidae
#> 13                  Artedius lateralis OR Artedius notospilotus       Cottidae
#> 54              Lepidopsetta bilineata OR Platichthys stellatus Pleuronectidae
#> 102           Scorpaenichthys marmoratus OR Leptocottus armatus           <NA>
#> 104 Sebastes caurinus OR Sebastes maliger OR Sebastes nebulosus     Sebastidae
#> 106                      Sebastes flavidus OR Sebastes melanops     Sebastidae
#>        genus species n_candidates
#> 11  Artedius    <NA>            2
#> 13  Artedius    <NA>            2
#> 54      <NA>    <NA>            2
#> 102     <NA>    <NA>            2
#> 104 Sebastes    <NA>            3
#> 106 Sebastes    <NA>            2
```

## Describe the sample before the diet

``` r

dv_summary(prep, by = "season")
#>       predator season n_stomachs n_records n_taxa records_per_stomach
#> 1 Harbour seal summer       1622      4379     97                2.70
#> 2 Harbour seal spring       1603      3787     90                2.36
#> 3 Harbour seal autumn       1112      2643     74                2.38
#> 4 Harbour seal winter        288       832     66                2.89
#>   total_weight
#> 1         1622
#> 2         1603
#> 3         1112
#> 4          288
```

The numbers describe this **collection of scats**, not a random sample
of all seal feeding in the Salish Sea. Seasonal contrasts are confounded
by site, year, laboratory and collection effort unless the design is
addressed.

## Calculate three different measures

The three columns below measure **different** things. `pct_occ` is the
share of *taxon–scat records*; it is not frequency of occurrence.
`pct_w` is the sample-normalized **relative DNA read signal**. `pct_fo`
is the proportion of represented scats in which a taxon was detected, at
the requested rank.

``` r

tree <- dv_tree(prep)
family <- dv_rank_table(tree, "Family")
head(family[order(-family$pct_w),
            c("label", "value_occ", "pct_occ", "pct_w")], 10)
#>             label value_occ   pct_occ     pct_w
#> 52   Merlucciidae      1755 15.076024 23.549770
#> 49      Clupeidae      1948 16.733958 22.119605
#> 84     Salmonidae      2308 19.826475 16.157408
#> 59   Embiotocidae       611  5.248690  5.437847
#> 64       Cottidae       756  6.494287  5.068601
#> 51        Gadidae       871  7.482175  4.935487
#> 46 Batrachoididae       608  5.222919  4.779365
#> 83 Pleuronectidae       598  5.137016  3.532447
#> 50    Engraulidae       233  2.001546  2.737961
#> 48       Alosidae       229  1.967185  1.914067
```

``` r

fo <- dv_fo_table(prep, rank = "family", denominator = "nonempty")
head(fo[order(-fo$pct_fo), c("taxon", "n_stomachs", "n_total", "pct_fo")], 10)
#>             taxon n_stomachs n_total pct_fo
#> 1       Clupeidae       1948    4625  42.12
#> 2    Merlucciidae       1755    4625  37.95
#> 3      Salmonidae       1309    4625  28.30
#> 4         Gadidae        803    4625  17.36
#> 5        Cottidae        610    4625  13.19
#> 6  Batrachoididae        608    4625  13.15
#> 7    Embiotocidae        595    4625  12.86
#> 8  Pleuronectidae        420    4625   9.08
#> 9     Engraulidae        233    4625   5.04
#> 10       Alosidae        229    4625   4.95
```

At each taxonomic rank, DietView retains an unidentified category. A
family label `NA` may occur beneath *different* parent taxa; use the
hierarchy when reading such cells rather than combining their labels
indiscriminately.

``` r

ranks <- unique(as.character(tree$rank))
totals <- vapply(ranks, function(r) {
  x <- tree[tree$rank == r, ]
  sum(x$pct_w)
}, numeric(1))
round(totals, 6)
#> Kingdom  Phylum   Class   Order  Family   Genus Species 
#>     100     100     100     100     100     100     100
stopifnot(all(abs(totals - 100) < 1e-4))
```

## Render and interpret a real interactive figure

``` r

dv_sunburst(tree, mode = "weight",
            title = "Harbour seal scats — within-scat relative DNA signal",
            subtitle = "Mean RRA, not prey biomass")
```

Read the rings from coarse to fine. Each ring partitions the same
normalized DNA signal, with white segments for material not identified
below a particular rank. A large wedge says **more DNA signal in these
samples**, not necessarily more prey individuals, biomass or energy.
Marker efficiency, primer bias, digestion, reference-library coverage
and laboratory methods all matter.

## Identification resolution and stratification

``` r

res <- dv_resolution(prep, by = "lab")
head(res[, c("lab", "finest_rank", "n_records", "p_records", "p_weight")], 12)
#>     lab finest_rank n_records   p_records    p_weight
#> 1   DFO       Order         3  0.14471780  0.05269395
#> 2   DFO      Family        17  0.82006753  0.58736356
#> 3   DFO       Genus        11  0.53063193  0.44303242
#> 4   DFO     Species      2042 98.50458273 98.91691007
#> 5   UBC       Order         3  0.06133715  0.10503449
#> 6   UBC      Family        53  1.08362298  0.89682217
#> 7   UBC       Genus        19  0.38846862  0.28006135
#> 8   UBC     Species      4816 98.46657125 98.71808199
#> 9  WDFW      Family       105  2.24502886  1.66822718
#> 10 WDFW       Genus        91  1.94569168  1.77833148
#> 11 WDFW     Species      4481 95.80927945 96.55344135
```

As a descriptive comparison, prepare two sample-level strata from the
frozen data. Do not interpret unadjusted contrasts as ecological trends.

``` r

season_sizes <- sort(table(frame$season), decreasing = TRUE)
season_sizes
#> 
#> summer spring autumn winter 
#>   1622   1603   1112    288
major <- names(season_sizes)[seq_len(min(2L, length(season_sizes)))]
season_tables <- lapply(major, function(s) {
  ds <- dat[!is.na(dat$season) & as.character(dat$season) == s, ]
  ps <- dv_prepare(ds, spec, taxonomy = "table", lineage = lin,
                   verbose = FALSE)
  tb <- dv_rank_table(dv_tree(ps), "Family")
  data.frame(season = s, tb[, c("label", "pct_w")])
})
head(do.call(rbind, season_tables), 12)
#>    season           label      pct_w
#> 73 summer      Salmonidae 13.1572756
#> 47 summer    Merlucciidae 29.2026101
#> 44 summer       Clupeidae 22.1525452
#> 46 summer         Gadidae  4.9911108
#> 72 summer  Pleuronectidae  3.7357248
#> 55 summer        Cottidae  3.3701229
#> 42 summer  Batrachoididae  3.9386076
#> 51 summer    Embiotocidae  3.5979804
#> 45 summer     Engraulidae  3.3211028
#> 57 summer  Gasterosteidae  0.8380219
#> 43 summer        Alosidae  1.4002699
#> 40 summer Petromyzontidae  0.4822053
```

## Export data and prepare a dashboard

[`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
produces a **scat-by-taxon** numeric matrix for downstream analysis;
rows are scats, not repeated prey records. The `weight` currency
contains sample-normalized proportions here.

``` r

m <- dv_matrix(prep, rank = "family", currency = "weight")
c(samples = nrow(m), families_and_unidentified = ncol(m))
#>                   samples families_and_unidentified 
#>                      4625                        57
head(round(rowSums(m), 5))
#> PG001 PG002 PG005 PG006 PG007 PG010 
#>     1     1     1     1     1     1
```

``` r

export <- file.path(tempdir(), "salish_seal_family_rra.csv")
utils::write.csv(m, export, row.names = TRUE)
file.exists(export)
#> [1] TRUE
```

Build a single-file HTML dashboard **on your own computer**. This
optional step is not run while the vignette is built, since it writes a
second large HTML file; run it interactively when you want to share the
result.

``` r

dv_build_html(prep,
  output = file.path(getwd(), "salish_seal_dna_dashboard.html"),
  bands = c("occurrence", "weight"), strata = c("season", "lab"),
  min_stomachs = 25,
  title = "Harbour seal DNA diet — Salish Sea (descriptive)")
```

## What to report, and what not to infer

Report the source, license, date, marker and laboratory, sampling unit,
preprocessing, unique sample count **per stratum**, treatment of
ambiguous taxa, classification version, metric/denominator, and
exclusions. In a scientific study, add sampling-design-aware uncertainty
intervals and evaluate batch, site and year effects. Do not equate DNA
reads or RRA to biomass or individual consumption; a detection in a scat
is not proof of a particular meal size. This vignette describes
detection patterns, not causal or population-level seasonal changes.

**References:** Thomas et al. (2022), *Scientific Data* 9:68,
<https://doi.org/10.1038/s41597-022-01152-5> (data CC0); Deagle et
al. (2019), *Molecular Ecology* 28:391–406,
<https://doi.org/10.1111/mec.14734>.
