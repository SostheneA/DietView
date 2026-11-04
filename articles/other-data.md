# Beyond stomachs: DNA metabarcoding, scats and other compositional data

DietView was written for stomach contents, but what it needs is more
general: a taxon name with a quantity, inside a sampling unit, with
covariates. The same structure describes diet from DNA metabarcoding of
scats or gut contents, pellets and regurgitates, catch composition from
a survey haul, or a benthic grab. This article shows how such data come
in:

- `dv_spec(weight_type = , unit_label = )` says what the quantity is
  (prey mass, sequence reads, or relative read abundance) and what one
  sampling unit is (a stomach, a scat, a sample), so figures and
  messages say the right thing;
- [`dv_resolution()`](https://sosthenea.github.io/DietView/reference/dv_resolution.md)
  reports the rank at which identification stops, with or without
  digestion stages;
- [`dv_from_wide()`](https://sosthenea.github.io/DietView/reference/dv_from_wide.md)
  reshapes a wide sample-by-taxon table into the long format;
- [`dv_parse_lineage()`](https://sosthenea.github.io/DietView/reference/dv_parse_lineage.md)
  splits the lineage strings that pipelines report into rank columns;
- `dv_prepare(taxonomy = "gbif")` resolves prey outside the marine realm
  against the GBIF Backbone Taxonomy, with the same rules and review log
  as WoRMS.

``` r

library(DietView)
```

## 1. A real case: harbour seal scats from the Salish Sea

`salish_seal_dna` is the public DNA metabarcoding diet of harbour seals
of the Salish Sea (Thomas et al. 2022): 4,625 scats from 52 haul-outs,
2012-2018, one row per prey taxon in a scat, with its share of the
scat’s prey DNA. Its lineage, resolved once against WoRMS, ships as
`salish_seal_lineage`.

``` r

head(salish_seal_dna[, c("sample_id", "site", "year", "season", "prey_label",
                         "reads_16S", "diet_fraction")])
#>   sample_id   site year season             prey_label reads_16S diet_fraction
#> 1  Pv12.001 Fraser 2012 spring      Alosa sapidissima      1376        0.9731
#> 2  Pv12.001 Fraser 2012 spring        Clupea pallasii        23        0.0163
#> 3  Pv12.001 Fraser 2012 spring  Metacarcinus magister        15        0.0106
#> 4  Pv12.002 Fraser 2012 spring        Clupea pallasii       993        0.2859
#> 5  Pv12.002 Fraser 2012 spring Gasterosteus aculeatus      2480        0.7141
#> 6  Pv12.003 Fraser 2012 spring      Alosa sapidissima         1        0.0385
```

The scat is the sampling unit, so it goes in the `stomach` role and is
named with `unit_label`. The DNA share is relative read abundance, so it
is declared as such rather than as a weight:

``` r

spec_seal <- dv_spec(predator = "predator", stomach = "sample_id",
                     prey_name = "prey_label", weight = "diet_fraction",
                     weight_type = "rra", unit_label = "scat",
                     covariates = c("season", "year", "site", "lab"))
seal <- dv_prepare(salish_seal_dna, spec_seal, taxonomy = "table",
                   lineage = salish_seal_lineage, verbose = FALSE)
seal
#> <dietview_prep>
#>   records   : 11641 
#>   scats     : 4625 
#>   predators : 1 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: season, year, site, lab 
#>   source    : table
```

### Occurrence and relative read abundance

Two views answer different questions. The share of prey records (with
one record per taxon and scat) and the frequency of occurrence say how
often a prey is eaten; the mean RRA says how much of the diet it makes
up, each scat weighing the same:

``` r

tree_seal <- dv_tree(seal)
fam <- dv_rank_table(tree_seal, "Family")
head(fam[order(-fam$pct_w), c("label", "pct_occ", "pct_w")], 6)
#>           label   pct_occ     pct_w
#> 52 Merlucciidae 15.076024 23.549770
#> 49    Clupeidae 16.733958 22.119605
#> 84   Salmonidae 19.826475 16.157408
#> 59 Embiotocidae  5.248690  5.437847
#> 64     Cottidae  6.494287  5.068601
#> 51      Gadidae  7.482175  4.935487
fo <- dv_fo_table(seal, rank = "species")
head(fo[order(-fo$pct_fo), c("taxon", "n_stomachs", "pct_fo")], 6)
#>                      taxon n_stomachs pct_fo
#> 1          Clupea pallasii       1948  42.12
#> 2     Merluccius productus       1755  37.95
#> 3       Porichthys notatus        608  13.15
#> 4 Oncorhynchus tshawytscha        591  12.78
#> 5      Gadus chalcogrammus        578  12.50
#> 6   Cymatogaster aggregata        575  12.43
```

Pacific herring is found in more scats than Pacific hake, but hake makes
up more of the diet when it is eaten: the two currencies rank them
differently, which is why DietView keeps both.

``` r

dv_sunburst(tree_seal, mode = "weight", title = "Harbour seal, Salish Sea (mean RRA)")
dv_build_html(seal, output = "salish_seal.html", cross = list("season"))
```

### Where identification stops

Metabarcoding resolves most prey to species, but not all: a short marker
can fail to separate close relatives, and the authors then report
alternatives (“*Sebastes flavidus* OR *Sebastes melanops*”). The frozen
lineage keeps what the candidates share (here the genus *Sebastes*), so
those records sit in the unidentified share below the genus, exactly as
a digested stomach item would.
[`dv_resolution()`](https://sosthenea.github.io/DietView/reference/dv_resolution.md)
measures it, here by laboratory:

``` r

res <- dv_resolution(seal, by = "lab")
res[, c("lab", "finest_rank", "n_records", "p_records", "p_weight")]
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

Without a digestion column, this is the identification-resolution
diagnostic; with one,
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
gives the same table by digestion stage.

## 2. From an ASV table

A typical output of a metabarcoding pipeline is one row per ASV, a
taxonomy string, and one column of read counts per sample. Here are six
ASVs from four seal scats (made-up numbers, to show the reshaping):

``` r

asv <- data.frame(
  asv = paste0("ASV", 1:6),
  taxonomy = c(
    "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Clupeiformes;f__Clupeidae;g__Clupea;s__harengus",
    "k__Animalia;p__Chordata;c__Actinopteri;o__Pleuronectiformes;f__;g__;s__",
    "k__Animalia;p__Mollusca;c__Cephalopoda;o__Myopsida;f__Loliginidae;g__Loligo;s__Loligo sp.",
    "Unassigned"),
  scat1 = c(5200, 800, 0, 300, 0, 40),
  scat2 = c(0, 0, 6100, 0, 900, 0),
  scat3 = c(1500, 0, 1500, 0, 0, 10),
  scat4 = c(0, 0, 0, 2500, 2500, 0))
meta <- data.frame(sample = paste0("scat", 1:4), predator = "grey seal",
                   season = c("winter", "winter", "summer", "summer"))
```

### Reshape and parse

[`dv_from_wide()`](https://sosthenea.github.io/DietView/reference/dv_from_wide.md)
turns it into one row per ASV in a sample, drops the zeros and joins the
sample metadata. ASV1 and ASV2 carry the same taxonomy;
`collapse_by = "taxonomy"` sums them, so that a taxon counts once per
sample in the shares of records and in %FO:

``` r

long <- dv_from_wide(asv, id_cols = c("asv", "taxonomy"), meta = meta,
                     collapse_by = "taxonomy")
long <- dv_parse_lineage(long, "taxonomy")
long[, c("sample", "reads", "order", "genus", "species", "prey_name")]
#>    sample reads             order  genus         species         prey_name
#> 1   scat1  6000        Gadiformes  Gadus    Gadus morhua      Gadus morhua
#> 2   scat1   300 Pleuronectiformes   <NA>            <NA> Pleuronectiformes
#> 3   scat1    40              <NA>   <NA>            <NA>              <NA>
#> 4   scat2  6100      Clupeiformes Clupea Clupea harengus   Clupea harengus
#> 5   scat2   900          Myopsida Loligo            <NA>            Loligo
#> 6   scat3  1500        Gadiformes  Gadus    Gadus morhua      Gadus morhua
#> 7   scat3  1500      Clupeiformes Clupea Clupea harengus   Clupea harengus
#> 8   scat3    10              <NA>   <NA>            <NA>              <NA>
#> 9   scat4  2500 Pleuronectiformes   <NA>            <NA> Pleuronectiformes
#> 10  scat4  2500          Myopsida Loligo            <NA>            Loligo
```

The empty fields (`f__`), the placeholder `Unassigned` and `Loligo sp.`
become `NA`: these records stay in the tree, as the explicit
unidentified category below the deepest rank they reached, exactly as a
stomach item identified only to order.

### Reads are not biomass

Sequence reads measure DNA, not prey mass: digestion, tissue type and
primer bias all distort the link (Deagle et al. 2019). DietView
therefore never labels reads as weight. Two summaries are offered:

- `weight_type = "reads"`: the share of all reads (pooled), which lets
  the samples with most reads dominate;
- `weight_type = "rra"`: the relative read abundance. The reads of each
  sample are divided by its total before summing, so every sample weighs
  the same and the share at a rank is the mean RRA over samples.

The shares of prey records stay available and, with one record per taxon
and sample, are the occurrence-based view;
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
gives the classical frequency of occurrence over samples.

``` r

spec <- dv_spec(predator = "predator", stomach = "sample",
                prey_name = "prey_name", weight = "reads",
                weight_type = "rra", unit_label = "scat",
                covariates = "season")
prep <- dv_prepare(long, spec, taxonomy = "columns", verbose = FALSE)
tree <- dv_tree(prep)
dv_rank_table(tree, "Order")
#>                label value_item value_occ pct_occ     value_w      pct_w
#> 9       Clupeiformes          1         2      20 1.369767442 34.2441860
#> 10        Gadiformes          1         2      20 1.444711110 36.1177778
#> 11 Pleuronectiformes          1         2      20 0.547318612 13.6829653
#> 12          Myopsida          1         2      20 0.628571429 15.7142857
#> 13                NA          1         2      20 0.009631407  0.2407852
dv_fo_table(prep, rank = "order")
#>    rank             taxon n_stomachs n_total pct_fo
#> 1 order      Clupeiformes          2       4     50
#> 2 order        Gadiformes          2       4     50
#> 3 order          Myopsida          2       4     50
#> 4 order                NA          2       4     50
#> 5 order Pleuronectiformes          2       4     50
```

`pct_w` is the mean RRA. Each figure and dashboard labels it as such:

``` r

dv_sunburst(tree, mode = "weight", title = "Grey seal scats (RRA)")
dv_build_html(prep, output = "seal_scats.html", cross = list("season"))
```

## 3. Which taxonomy?

Three routes, by what the data already carry:

| The data carry | Use | Why |
|----|----|----|
| A lineage string from the assignment step | [`dv_parse_lineage()`](https://sosthenea.github.io/DietView/reference/dv_parse_lineage.md) then `taxonomy = "columns"` | Keeps the reference taxonomy the sequences were assigned with (NCBI, SILVA, BOLD), and needs no network. |
| Prey names, marine prey | `taxonomy = "worms"` | WoRMS is the authority for marine taxa. |
| Prey names, terrestrial or freshwater prey | `taxonomy = "gbif"` | The GBIF Backbone covers all kingdoms. |

The names produced by
[`dv_parse_lineage()`](https://sosthenea.github.io/DietView/reference/dv_parse_lineage.md)
can also be sent to WoRMS or GBIF, to harmonize a metabarcoding data set
with stomach data classified there:

``` r

prep_gbif <- dv_prepare(long, spec, taxonomy = "gbif", kingdom = "Animalia")
dv_taxonomy_report(prep_gbif)
```

GBIF matches are logged like WoRMS matches, with two extra review flags:
`"higherrank"` (the name is unknown to GBIF, but a coarser taxon in it
is known, so the lineage stops there) and `low_confidence`. The GBIF
Backbone has no class for some groups (ray-finned fishes sit directly
under Chordata); the default `gaps = "label"` fills that rank as
`"Chordata (no class)"` rather than counting the records as
unidentified.

## 4. Other compositional data

Catch composition, plankton or benthos tables often come with samples in
rows and taxa in columns. `taxa_in = "columns"` reads that layout:

``` r

haul <- data.frame(haul = c("H1", "H2"), stratum = c("401", "402"),
                   `Gadus morhua` = c(12.4, 0), `Clupea harengus` = c(30.1, 55.0),
                   check.names = FALSE)
catch <- dv_from_wide(haul, taxa_in = "columns", id_cols = c("haul", "stratum"),
                      sample_col = "haul", value_col = "kg")
catch
#>   haul stratum       prey_name   kg
#> 1   H1     401    Gadus morhua 12.4
#> 2   H1     401 Clupea harengus 30.1
#> 3   H2     402 Clupea harengus 55.0
```

Then declare the haul as the sampling unit (`unit_label = "haul"`), the
stratum as a covariate (with a constant predator column, e.g. the
survey), and the weight in kg as a mass. Everything downstream
(sunbursts, covariate strata, the dashboard) works unchanged.

## 5. What does not fit

Stable isotopes and fatty acids do not identify prey: mixing models
(MixSIAR, simmr, QFASA) estimate the contributions of a few source
groups chosen by the analyst, with posterior uncertainty. A sunburst of
posterior means would hide that uncertainty and the shallow, often
functional, grouping of the sources. DietView is not meant for those
outputs; it can, however, hold the stomach or DNA data from the same
predators on one taxonomic backbone, the reference against which
isotope-based diets are often compared.

## References

Thomas, A. C., Deagle, B., Nordstrom, C., Majewski, S., Nelson, B. W.,
Acevedo-Gutiérrez, A., Jeffries, S., Moore, J., Louden, A., Allegue, H.,
Pearson, S., Schmidt, M., & Trites, A. W. (2022). Data on the diets of
Salish Sea harbour seals from DNA metabarcoding. *Scientific Data*, 9,
68. <https://doi.org/10.1038/s41597-022-01152-5>

Deagle, B. E., Thomas, A. C., McInnes, J. C., Clarke, L. J., Vesterinen,
E. J., Clare, E. L., Kartzinel, T. R., & Eveson, J. P. (2019). Counting
with DNA in metabarcoding studies: How should we convert sequence reads
to dietary data? *Molecular Ecology*, 28(2), 391-406.
