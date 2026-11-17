# Complete case study: morphological prey remains in pellets or scats

## Research question, sample frame and limitations

This example asks which prey remains were recorded in a collection of
pellets and how the picture changes when we distinguish records,
estimated numbers of individuals and sample-based occurrence.

The pellet survey is simulated; its observations do not describe a real
predator, location or feeding process. Pellets, regurgitates, scats and
stomachs can share a data structure, although preservation and digestion
affect each material differently. Recovered remains therefore cannot be
treated as a complete measure of ingested biomass.

**Sampling unit:** one pellet, with a unique `pellet_id` even when the
same bird or site was sampled repeatedly. **Record:** one prey category
observed in that pellet. **Count:** a *minimum number of prey
individuals* estimated from diagnostic remains, not the count of
otoliths, feathers or fragments.

``` r

library(DietView)
set.seed(412)
frame <- data.frame(
  pellet_id = sprintf("PEL%02d", 1:24),
  predator = rep(c("Illustrative predator A", "Illustrative predator B"), each = 12),
  season = rep(rep(c("spring", "autumn"), each = 6), 2),
  site = rep(c("Site1", "Site2"), 12)
)
classification <- data.frame(
  prey_name = c("Clupea harengus", "Crangon crangon",
                "Unidentified fish", "Unidentified animal remains"),
  kingdom = rep("Animalia", 4),
  phylum = c("Chordata", "Arthropoda", "Chordata", NA),
  class = c("Actinopteri", "Malacostraca", NA, NA),
  order = c("Clupeiformes", "Decapoda", NA, NA),
  family = c("Clupeidae", "Crangonidae", NA, NA),
  genus = c("Clupea", "Crangon", NA, NA),
  species = c("Clupea harengus", "Crangon crangon", NA, NA)
)
i <- rep(seq_len(nrow(frame)), each = nrow(classification))
j <- rep(seq_len(nrow(classification)), times = nrow(frame))
minimum_individuals <- stats::rpois(length(i), lambda = c(1.5, 1.2, 0.8, 0.4)[j])
minimum_individuals[i %in% c(1, 14)] <- 0L  # deliberately empty sampled pellets
records <- cbind(frame[i, ], classification[j, ],
                 n_individuals = minimum_individuals)
records <- records[records$n_individuals > 0L, , drop = FALSE]
rownames(records) <- NULL
frame$empty <- !(frame$pellet_id %in% records$pellet_id)
head(records[, c("pellet_id", "predator", "prey_name", "n_individuals")])
#>   pellet_id                predator                   prey_name n_individuals
#> 1     PEL02 Illustrative predator A             Crangon crangon             2
#> 2     PEL03 Illustrative predator A             Clupea harengus             5
#> 3     PEL03 Illustrative predator A           Unidentified fish             2
#> 4     PEL04 Illustrative predator A             Crangon crangon             3
#> 5     PEL04 Illustrative predator A Unidentified animal remains             2
#> 6     PEL05 Illustrative predator A             Clupea harengus             2
```

## Validate the long table and examined-sample inventory

The inventory must keep the **two sampled pellets with no prey
records**. Otherwise they disappear from the long table and the
proportion of sampled pellets with detections is exaggerated. A real
zero needs a clear field protocol: an empty bag, an uninformative sample
or a pellet with no identifiable remains may represent different states.

``` r

stopifnot(!anyDuplicated(frame$pellet_id))
stopifnot(!anyNA(records$pellet_id), all(records$n_individuals > 0))
stopifnot(!anyDuplicated(records[c("pellet_id", "prey_name")]))
c(examined = nrow(frame), with_remains = length(unique(records$pellet_id)),
  without_remains = sum(frame$empty))
#>        examined    with_remains without_remains 
#>              24              22               2
```

``` r

spec <- dv_spec(predator = "predator", stomach = "pellet_id",
                prey_name = "prey_name", count = "n_individuals",
                unit_label = "pellet", covariates = c("season", "site"))
prep <- dv_prepare(records, spec, taxonomy = "columns",
                   stomachs = frame, empty_col = "empty", verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 53 
#>   pellets   : 22 
#>   predators : 2 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: season, site 
#>   source    : columns 
#>   examined  : 24 pellets, 2 empty
```

The rank columns are *explicitly assigned* for the simulated data; do
not make up family/species names to fill missing ranks in real samples.
When you have only prey names rather than ranks, resolve them with
WoRMS/GBIF and audit their matches, or use a checked frozen lookup
table.

## Quantities: records, individuals, and occurrence

With one row per taxon and pellet, **record share** reflects how
frequently categories appear among the observed records; it is not a
sample-based frequency of occurrence. DietView can also sum the
**estimated number of prey individuals** via `currency = "numbers"`.
Only use that option if the counts really estimate individuals, rather
than fragments or sequencing reads.

``` r

tree_records <- dv_tree(prep, currency = "records")
tree_numbers <- dv_tree(prep, currency = "numbers")
rec <- dv_rank_table(tree_records, "Class")
num <- dv_rank_table(tree_numbers, "Class")
head(rec[, c("label", "pct_occ")])
#>          label  pct_occ
#> 5 Malacostraca 32.07547
#> 6  Actinopteri 26.41509
#> 7           NA 22.64151
#> 8           NA 18.86792
head(num[, c("label", "pct_occ")])  # numerical share (%N)
#>          label  pct_occ
#> 6  Actinopteri 34.88372
#> 5 Malacostraca 31.39535
#> 7           NA 17.44186
#> 8           NA 16.27907
```

`pct_occ` is the column name in either tree; its *meaning* is recorded
by the `currency` attribute, so report it as record share or numerical
share (%N) accordingly.

The denominator of %FO must be declared. Here, all 24 pellets were
examined, and the inventory includes the empty ones.

``` r

fo_nonempty <- dv_fo_table(prep, rank = "class",
                           denominator = "nonempty")
fo_examined <- dv_fo_table(prep, rank = "class",
                           denominator = "examined")
head(fo_nonempty[, c("taxon", "n_stomachs", "n_total", "pct_fo")])
#>          taxon n_stomachs n_total pct_fo
#> 1 Malacostraca         17      22  77.27
#> 2           NA         16      22  72.73
#> 3  Actinopteri         14      22  63.64
head(fo_examined[, c("taxon", "n_stomachs", "n_total", "pct_fo")])
#>          taxon n_stomachs n_total pct_fo
#> 1 Malacostraca         17      24  70.83
#> 2           NA         16      24  66.67
#> 3  Actinopteri         14      24  58.33
```

The `n_stomachs` and `n_total` names in DietView’s output are historical
interface labels; for this analysis they count **pellets**, not
stomachs. %FO across prey categories need not add to 100%, because a
pellet can contain multiple taxa.

## Visualization and unidentified remains

``` r

dv_sunburst(tree_records, mode = "occurrence",
            title = "Morphological pellets (simulated)",
            subtitle = "Share of prey-category records, unidentified included")
```

A white wedge below *Chordata* represents the observed fish fragments
that could not be placed at class or a finer rank. Material assigned
only to *Animalia* is even less resolved. Neither category should be
silently dropped and the remainder rescaled to 100%.

``` r

dv_resolution(prep, by = "season")
#>   season finest_rank n_records weight p_records p_weight
#> 1 autumn     Kingdom         6      0  20.68966       NA
#> 2 autumn      Phylum         6      0  20.68966       NA
#> 3 autumn     Species        17      0  58.62069       NA
#> 4 spring     Kingdom         4      0  16.66667       NA
#> 5 spring      Phylum         6      0  25.00000       NA
#> 6 spring     Species        14      0  58.33333       NA
```

This is **taxonomic resolution**, not a calibrated digestion index. Do
not use
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
unless genuine, interpretable digestion stages were recorded for the
sampled units or prey remains.

## Export with explicitly represented empty pellets

``` r

m <- dv_matrix(prep, rank = "family", currency = "fo",
               include_empty = TRUE)
c(pellets = nrow(m), columns = ncol(m))
#> pellets columns 
#>      24       3
stopifnot(nrow(m) == nrow(frame))
head(rowSums(m))
#> PEL02 PEL03 PEL04 PEL05 PEL06 PEL07 
#>     1     2     2     2     3     3
utils::write.csv(m, file.path(tempdir(), "pellet_presence_matrix.csv"))
```

Here `currency = "fo"` produces a 0/1 **pellet × prey category** matrix.
A zero is *no recorded remains* in that pellet, not proof the prey was
not eaten. The sampling inventory retains the two observed empty pellets
as all-zero rows; a blank or failed laboratory examination should
instead be flagged as unknown, not automatically counted as empty.

``` r

dv_build_html(prep,
  output = file.path(getwd(), "pellet_remains_demo.html"),
  bands = "occurrence", currency = "numbers", strata = "season",
  title = "Simulated pellets: minimum prey individuals")
```

## Scientific interpretation and transfer to real pellets or scats

Report how units were collected, repeated observations from the same
predator, identification rules, the anatomical basis of minimum
individual counts, empty/failed samples, the taxonomic resolution, %FO
denominator, all exclusions, and measurement uncertainty. Distinguish
fragment frequency, minimum prey counts, and recovery probability.
Digestion resistance and preservation can make hard parts
overrepresented. For DNA-derived scats, do **not** reuse the
minimum-individual workflow: use the [DNA case
study](https://sosthenea.github.io/DietView/articles/case-study-dna-seals.md)
instead.
