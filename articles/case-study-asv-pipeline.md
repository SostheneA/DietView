# Complete case study: from an ASV table to a DNA diet report

## The question and the raw export

Sequencing pipelines often export a table with ASVs in rows and samples
in columns, alongside a taxonomic assignment for each sequence variant.
This example reshapes that output for DietView, checks the read totals
and retains unresolved assignments. It compares pooled read proportions
with mean relative read abundance (RRA), then produces a figure, a
sample matrix and an optional dashboard.

The read counts in this example are simulated to illustrate the
workflow. They cannot support biological conclusions. The [Salish Sea
harbour seal
case](https://sosthenea.github.io/DietView/articles/case-study-dna-seals.md)
uses published data.

``` r

library(DietView)
asv <- data.frame(
  asv = paste0("ASV", 1:8),
  taxonomy = c(
    "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Clupeiformes;f__Clupeidae;g__Clupea;s__harengus",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Pleuronectiformes;f__;g__;s__",
    "k__Animalia;p__Arthropoda;c__Malacostraca;o__Euphausiacea;f__Euphausiidae;g__;s__",
    "k__Animalia;p__Mollusca;c__Cephalopoda;o__Myopsida;f__Loliginidae;g__Loligo;s__Loligo sp.",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__;s__",
    "Unassigned"
  ),
  S1 = c(120, 80, 0, 0, 20, 0, 5, 2),
  S2 = c(0, 0, 520, 0, 25, 5, 0, 8),
  S3 = c(75, 30, 0, 22, 0, 0, 10, 1),
  S4 = c(0, 0, 90, 40, 60, 0, 0, 5),
  S5 = c(0, 0, 0, 30, 0, 20, 0, 2),
  S6 = c(400, 0, 150, 0, 0, 0, 12, 3)
)
meta <- data.frame(
  sample = paste0("S", 1:6),
  predator = rep("Illustrative marine predator", 6),
  season = c("winter", "winter", "winter", "summer", "summer", "summer"),
  site = c("A", "A", "B", "A", "B", "B")
)
head(asv[, 1:4])
#>    asv
#> 1 ASV1
#> 2 ASV2
#> 3 ASV3
#> 4 ASV4
#> 5 ASV5
#> 6 ASV6
#>                                                                                    taxonomy
#> 1        k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua
#> 2        k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua
#> 3 k__Animalia;p__Chordata;c__Actinopteri;o__Clupeiformes;f__Clupeidae;g__Clupea;s__harengus
#> 4                   k__Animalia;p__Chordata;c__Actinopteri;o__Pleuronectiformes;f__;g__;s__
#> 5         k__Animalia;p__Arthropoda;c__Malacostraca;o__Euphausiacea;f__Euphausiidae;g__;s__
#> 6 k__Animalia;p__Mollusca;c__Cephalopoda;o__Myopsida;f__Loliginidae;g__Loligo;s__Loligo sp.
#>    S1  S2
#> 1 120   0
#> 2  80   0
#> 3   0 520
#> 4   0   0
#> 5  20  25
#> 6   0   5
meta
#>   sample                     predator season site
#> 1     S1 Illustrative marine predator winter    A
#> 2     S2 Illustrative marine predator winter    A
#> 3     S3 Illustrative marine predator winter    B
#> 4     S4 Illustrative marine predator summer    A
#> 5     S5 Illustrative marine predator summer    B
#> 6     S6 Illustrative marine predator summer    B
```

**Unit:** one sample (`S1`–`S6`). **Quantity:** DNA read count.
**Taxonomic source:** illustrative lineage labels, not verified WoRMS
assignments. **Important prerequisite for real data:** quality-control
reads, negative controls, remove non-target/host sequences, check
contamination and assignment thresholds *before* the workflow below.
DietView does not perform sequence denoising, primer filtering or
taxonomic assignment.

## Audit counts and sampling metadata

``` r

reads <- as.matrix(asv[setdiff(names(asv), c("asv", "taxonomy"))])
stopifnot(!anyNA(reads), all(reads >= 0), all(reads == round(reads)))
stopifnot(!anyDuplicated(meta$sample), identical(colnames(reads), meta$sample))
colSums(reads)
#>  S1  S2  S3  S4  S5  S6 
#> 227 558 138 195  52 565
sum(reads)
#> [1] 1735
```

Read depths differ substantially. A pooled-read percentage gives a deep
library more influence than a shallow one, whereas mean RRA gives each
positive sample equal weight.

## Convert ASVs into taxon–sample records

ASV1 and ASV2 have the **same reported taxonomic assignment**. Here we
aggregate their read counts **within sample** for a taxon-level summary,
so that the taxon–sample record share is not inflated by multiple ASVs
assigned to one named category. This does **not** imply that the
original ASVs are biologically identical or interchangeable. Preserve
the original ASV-level table for sequence-level questions and
reproducibility.

``` r

long <- dv_from_wide(asv, taxa_in = "rows",
                     id_cols = c("asv", "taxonomy"),
                     sample_col = "sample", value_col = "reads",
                     meta = meta, collapse_by = "taxonomy")
head(long)
#>   sample
#> 1     S1
#> 2     S1
#> 3     S1
#> 4     S1
#> 5     S2
#> 6     S2
#>                                                                             taxonomy
#> 1                                                                         Unassigned
#> 2  k__Animalia;p__Arthropoda;c__Malacostraca;o__Euphausiacea;f__Euphausiidae;g__;s__
#> 3            k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__;s__
#> 4 k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua
#> 5                                                                         Unassigned
#> 6  k__Animalia;p__Arthropoda;c__Malacostraca;o__Euphausiacea;f__Euphausiidae;g__;s__
#>   reads                     predator season site
#> 1     2 Illustrative marine predator winter    A
#> 2    20 Illustrative marine predator winter    A
#> 3     5 Illustrative marine predator winter    A
#> 4   200 Illustrative marine predator winter    A
#> 5     8 Illustrative marine predator winter    A
#> 6    25 Illustrative marine predator winter    A
stopifnot(sum(long$reads) == sum(reads))
```

The lineage parser handles rank prefixes, blank ranks, `sp.` and the
`Unassigned` record. Missing taxonomic ranks become genuine `NA` values;
unassigned DNA remains in the denominator rather than silently
disappearing.

``` r

long <- dv_parse_lineage(long, col = "taxonomy")
head(long[, c("sample", "reads", "prey_name", "phylum",
                "family", "species")], 10)
#>    sample reads       prey_name     phylum       family         species
#> 1      S1     2            <NA>       <NA>         <NA>            <NA>
#> 2      S1    20    Euphausiidae Arthropoda Euphausiidae            <NA>
#> 3      S1     5         Gadidae   Chordata      Gadidae            <NA>
#> 4      S1   200    Gadus morhua   Chordata      Gadidae    Gadus morhua
#> 5      S2     8            <NA>       <NA>         <NA>            <NA>
#> 6      S2    25    Euphausiidae Arthropoda Euphausiidae            <NA>
#> 7      S2   520 Clupea harengus   Chordata    Clupeidae Clupea harengus
#> 8      S2     5          Loligo   Mollusca  Loliginidae            <NA>
#> 9      S3     1            <NA>       <NA>         <NA>            <NA>
#> 10     S3    10         Gadidae   Chordata      Gadidae            <NA>
```

For real sequences, audit whether an ASV or several ASVs should count as
one *taxon detection*. The decision depends on the reporting question
and on the confidence of the reference classification. An unassigned
record is a DNA observation but not a named prey species.

## Declare the input contract and normalize within samples

``` r

spec_rra <- dv_spec(
  predator = "predator", stomach = "sample", prey_name = "prey_name",
  weight = "reads", weight_type = "rra", unit_label = "sample",
  covariates = c("season", "site")
)
prep <- dv_prepare(long, spec_rra, taxonomy = "columns", verbose = FALSE)
#> Warning: 6 record(s) have no usable prey key and cannot be placed in any taxon.
prep
#> <dietview_prep>
#>   records   : 23 
#>   samples   : 6 
#>   predators : 1 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: season, site 
#>   source    : columns
```

[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
keeps the original `reads` column and adds a sample-normalized column
(`prep$spec$weight`). A sample’s contributions should add to one, even
when some reads cannot be named to species.

``` r

rra_col <- prep$spec$weight
rra_totals <- tapply(prep$data[[rra_col]], prep$data$sample, sum)
round(rra_totals, 8)
#> S1 S2 S3 S4 S5 S6 
#>  1  1  1  1  1  1
stopifnot(all(abs(rra_totals - 1) < 1e-8))
```

### Pooled reads versus mean RRA

Use **two distinct specifications**: `"reads"` keeps pooled read counts;
`"rra"` standardizes each sample before pooling. `pct_w` is the
percentage of the quantity declared in the specification, not a measure
of prey mass.

``` r

spec_reads <- dv_spec(
  predator = "predator", stomach = "sample", prey_name = "prey_name",
  weight = "reads", weight_type = "reads", unit_label = "sample",
  covariates = c("season", "site")
)
prep_reads <- dv_prepare(long, spec_reads, taxonomy = "columns",
                         verbose = FALSE)
#> Warning: 6 record(s) have no usable prey key and cannot be placed in any taxon.
pooled <- dv_rank_table(dv_tree(prep_reads), "Phylum")
mean_rra <- dv_rank_table(dv_tree(prep), "Phylum")
comparison <- merge(pooled[, c("label", "pct_w")],
                    mean_rra[, c("label", "pct_w")], by = "label",
                    suffixes = c("_pooled_reads", "_mean_rra"))
comparison
#>        label pct_w_pooled_reads pct_w_mean_rra
#> 1 Arthropoda           6.051873       7.343348
#> 2   Chordata          91.296830      84.433616
#> 3   Mollusca           1.440922       6.559599
#> 4         NA           1.210375       1.663436
```

These two percentages can differ because sequencing depth differs
between samples; *neither* is a percentage of ingested biomass. Always
state which was reported, and never mix them without a documented
rationale.

## Occurrence, rank uncertainty and visualization

``` r

tree <- dv_tree(prep)
dv_rank_table(tree, "Family")
#>           label value_item value_occ   pct_occ    value_w     pct_w
#> 19      Gadidae          2         6 26.086957 2.46562057 41.093676
#> 22           NA          1         6 26.086957 0.09980617  1.663436
#> 17 Euphausiidae          1         3 13.043478 0.44060090  7.343348
#> 18    Clupeidae          1         3 13.043478 1.65892483 27.648747
#> 20           NA          1         3 13.043478 0.94147157 15.691193
#> 21  Loliginidae          1         2  8.695652 0.39357596  6.559599
dv_fo_table(prep, rank = "family")
#>     rank        taxon n_stomachs n_total pct_fo
#> 1 family           NA          6       6 100.00
#> 2 family    Clupeidae          3       6  50.00
#> 3 family Euphausiidae          3       6  50.00
#> 4 family      Gadidae          3       6  50.00
#> 5 family  Loliginidae          2       6  33.33
dv_resolution(prep)
#>   finest_rank n_records     weight p_records  p_weight
#> 1       Order         3 0.94147157 13.043478 15.691193
#> 2      Family         6 0.55633004 26.086957  9.272167
#> 3       Genus         2 0.39357596  8.695652  6.559599
#> 4     Species         6 4.00881626 26.086957 66.813604
#> 5  Unresolved         6 0.09980617 26.086957  1.663436
```

`pct_occ` counts distinct taxon–sample rows after collapsing repeated
ASVs. `pct_fo` is the proportion of positive sample IDs with a taxon
detection; it is not a probability of feeding and need not sum to 100
across taxa. `pct_w` is mean RRA. The explicit unidentified node matters
especially for the `Unassigned` reads and higher-rank matches.

``` r

dv_sunburst(tree, mode = "weight", title = "Illustrative DNA diet",
            subtitle = "Mean within-sample RRA; simulated ASV counts")
```

``` r

res <- dv_resolution(prep, by = "season")
res[, c("season", "finest_rank", "n_records", "p_weight")]
#>    season finest_rank n_records   p_weight
#> 1  summer       Order         2 26.0683761
#> 2  summer      Family         2 10.9643749
#> 3  summer       Genus         1 12.8205128
#> 4  summer     Species         3 47.8329930
#> 5  summer  Unresolved         3  2.3137433
#> 6  winter       Order         1  5.3140097
#> 7  winter      Family         4  7.5799598
#> 8  winter       Genus         1  0.2986858
#> 9  winter     Species         3 85.7942159
#> 10 winter  Unresolved         3  1.0131289
```

## Export a sample-by-taxon matrix

``` r

m <- dv_matrix(prep, rank = "family", currency = "weight")
round(m, 3)
#>    Clupeidae Euphausiidae Gadidae Loliginidae    NA
#> S1     0.000        0.088   0.903       0.000 0.009
#> S2     0.932        0.045   0.000       0.009 0.014
#> S3     0.000        0.000   0.833       0.000 0.167
#> S4     0.462        0.308   0.000       0.000 0.231
#> S5     0.000        0.000   0.000       0.385 0.615
#> S6     0.265        0.000   0.729       0.000 0.005
stopifnot(nrow(m) == nrow(meta))
utils::write.csv(m, file.path(tempdir(), "asv_example_family_rra.csv"))
```

A zero means no **retained** read assignment for a family in that
sample, not biological proof of absence. A read-positive sample defines
a within-sample RRA denominator; failed or fully filtered assays need a
separate sample inventory and should not be silently counted as
negatives. Preserve the ASV table, controls, filtering script, reference
taxonomy database and version, and the detection pipeline.

``` r

dv_build_html(prep,
  output = file.path(getwd(), "asv_demo_dashboard.html"),
  strata = "season", bands = c("occurrence", "weight"),
  title = "ASV tutorial: read-based diet (simulated)")
```

## Reporting checklist and limitations

A complete report gives read-depth distributions, negative and positive
controls, thresholds, sample exclusions, marker/primer targets, DNA
extraction batch, taxonomy reference and version, unresolved fraction,
sample-level replication, currency and denominator, and uncertainty from
the sampling design. Do not read RRA as biomass, %FO as ingestion
probability, or pooled read share as an unbiased estimate of the prey’s
importance.

For a worked analysis of real scats, continue to [harbour seal DNA in
the Salish
Sea](https://sosthenea.github.io/DietView/articles/case-study-dna-seals.md).
For samples with **no prey sequence retained**, keep a separate sample
inventory; otherwise a long table cannot reveal their existence.

**Further reading:** Deagle et al. (2019), *Molecular Ecology*
28:391–406, <https://doi.org/10.1111/mec.14734>.
