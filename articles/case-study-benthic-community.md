# Complete case study: benthic grab community composition

## When can community data use a diet-visualization package?

DietView’s **taxonomic composition and resolution** machinery also works
for benthic grabs, plankton nets and other sample-by-taxon matrices. But
a benthic taxon is not necessarily prey, and the result must **not** be
called a predator diet. This end-to-end example uses simulated
macrofaunal grabs with counts, measured wet mass and a frozen local
lineage. No real environmental effect is being claimed.

**Question:** How is recorded macrofaunal abundance and wet biomass
partitioned among taxa, and how much remains identified only to broad
taxonomic ranks?

**Unit:** one grab of **0.1 m²** in this synthetic survey. **Quantity:**
individuals (numbers currency) and wet grams (mass currency).
**Grouping:** habitat. **Required DietView role:**
`community = "Benthic grab"` is a constant assemblage label, not a
predator.

## Reproducible simulated sampling and zero samples

``` r

library(DietView)
set.seed(197)
frame <- data.frame(
  grab_id = sprintf("G%02d", 1:30),
  habitat = rep(c("sand", "mud"), each = 15),
  area_m2 = 0.1, community = "Benthic grab"
)
taxonomy <- data.frame(
  taxon = c("Hediste diversicolor", "Mytilus edulis", "Limecola balthica",
            "Gammarus sp.", "Unidentified macrofauna"),
  kingdom = rep("Animalia", 5),
  phylum = c("Annelida", "Mollusca", "Mollusca", "Arthropoda", NA),
  class = c("Polychaeta", "Bivalvia", "Bivalvia", "Malacostraca", NA),
  order = c("Phyllodocida", "Mytilida", "Cardiida", "Amphipoda", NA),
  family = c("Nereididae", "Mytilidae", "Tellinidae", "Gammaridae", NA),
  genus = c("Hediste", "Mytilus", "Limecola", "Gammarus", NA),
  species = c("Hediste diversicolor", "Mytilus edulis", "Limecola balthica",
              NA, NA)
)
i <- rep(seq_len(nrow(frame)), each = nrow(taxonomy))
j <- rep(seq_len(nrow(taxonomy)), times = nrow(frame))
n_ind <- stats::rpois(length(i), lambda = c(4, 2, 3, 6, 1.2)[j])
n_ind[i %in% c(1, 18)] <- 0L  # known grabs without recorded animals
wet_g <- round(n_ind * c(0.8, 1.4, 1.1, 0.2, 0.5)[j] *
               stats::runif(length(i), 0.8, 1.2), 3)
long <- cbind(frame[i, ], taxonomy[j, ],
              individuals = n_ind, wet_g = wet_g)
long <- long[long$individuals > 0, , drop = FALSE]
rownames(long) <- NULL
frame$empty <- !(frame$grab_id %in% long$grab_id)
head(long[, c("grab_id", "habitat", "taxon", "individuals", "wet_g")])
#>   grab_id habitat                   taxon individuals wet_g
#> 1     G02    sand    Hediste diversicolor           4 3.673
#> 2     G02    sand          Mytilus edulis           3 4.390
#> 3     G02    sand       Limecola balthica           2 2.400
#> 4     G02    sand            Gammarus sp.           7 1.291
#> 5     G02    sand Unidentified macrofauna           1 0.482
#> 6     G03    sand    Hediste diversicolor           5 3.707
```

## Validate units, counts and coverage

``` r

stopifnot(!anyDuplicated(frame$grab_id), !anyNA(long$grab_id))
stopifnot(all(long$individuals == round(long$individuals)),
          all(long$individuals >= 0), all(long$wet_g >= 0))
c(grabs_examined = nrow(frame), grabs_without_detections = sum(frame$empty),
  individuals = sum(long$individuals), wet_biomass_g = sum(long$wet_g))
#>           grabs_examined grabs_without_detections              individuals 
#>                    30.00                     2.00                   447.00 
#>            wet_biomass_g 
#>                   328.59
```

Because all grabs have the same sampled area, their raw counts and
masses are comparably scaled in this example. If areas differ, calculate
density and biomass per area *explicitly* outside DietView before
statistical comparisons; `currency = "numbers"` is for organism counts,
not fractional densities.

## Prepare the taxonomy, including unknown material

A locally checked taxonomy is supplied as **columns**. This avoids a
network lookup and makes the example reproducible. A real workflow
should retain original organism IDs, taxonomic authority/version and the
rules used to merge uncertain or outdated names.

``` r

spec <- dv_spec(predator = "community", stomach = "grab_id",
                prey_name = "taxon", count = "individuals", weight = "wet_g",
                weight_type = "mass", unit_label = "grab",
                covariates = "habitat")
prep <- dv_prepare(long, spec, taxonomy = "columns",
                   stomachs = frame, empty_col = "empty", verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 126 
#>   grabs     : 28 
#>   predators : 1 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: habitat 
#>   source    : columns 
#>   examined  : 30 grabs, 2 empty
```

`Unidentified macrofauna` has a nonempty record with only the kingdom
known; its counts and mass remain in the denominators. **Not
identified** is not the same thing as zero organisms.

## Compare abundance and wet biomass without conflating them

``` r

by_records <- dv_tree(prep, currency = "records")
by_individuals <- dv_tree(prep, currency = "numbers")
rec <- dv_rank_table(by_records, "Phylum")
num <- dv_rank_table(by_individuals, "Phylum")
head(rec[, c("label", "value_occ", "pct_occ", "value_w", "pct_w")])
#>        label value_occ  pct_occ value_w     pct_w
#> 4   Mollusca        51 40.47619 196.394 59.768709
#> 2   Annelida        28 22.22222  85.915 26.146566
#> 3 Arthropoda        28 22.22222  30.211  9.194133
#> 5         NA        19 15.07937  16.070  4.890593
head(num[, c("label", "value_occ", "pct_occ", "value_w", "pct_w")])
#>        label value_occ   pct_occ value_w     pct_w
#> 4   Mollusca       158 35.346756 196.394 59.768709
#> 3 Arthropoda       148 33.109620  30.211  9.194133
#> 2   Annelida       110 24.608501  85.915 26.146566
#> 5         NA        31  6.935123  16.070  4.890593
```

In `by_individuals`, `value_occ` is the **total number of organisms**
and `pct_occ` is %N; in `by_records` they are observed taxon–grab row
counts and record shares. Both trees retain the same `value_w` (wet
grams) and `pct_w` (% of recorded wet biomass). They answer different
questions and may give different rankings.

``` r

dv_sunburst(by_individuals, mode = "occurrence",
            title = "Benthic grabs — simulated individuals",
            subtitle = "Numerical abundance, not predator diet")
```

## Occurrence frequency, taxonomic resolution and sampling

For a community survey,
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
reports **grab-occurrence** (percentage of sampled grabs where the taxon
was observed). It must not be described as predator dietary %FO. The
complete grab inventory supplies the examined sample denominator,
including the two known no-detection grabs.

``` r

fo <- dv_fo_table(prep, rank = "family", denominator = "examined")
head(fo[, c("taxon", "n_stomachs", "n_total", "pct_fo")], 8)
#>        taxon n_stomachs n_total pct_fo
#> 1 Gammaridae         28      30  93.33
#> 2 Nereididae         28      30  93.33
#> 3 Tellinidae         27      30  90.00
#> 4  Mytilidae         24      30  80.00
#> 5         NA         19      30  63.33
```

``` r

dv_resolution(prep, by = "habitat")
#>   habitat finest_rank n_records  weight p_records  p_weight
#> 1     mud     Kingdom         9   7.990  14.51613  5.166037
#> 2     mud       Genus        14  12.763  22.58065  8.252082
#> 3     mud     Species        39 133.911  62.90323 86.581881
#> 4    sand     Kingdom        10   8.080  15.62500  4.645654
#> 5    sand       Genus        14  17.448  21.87500 10.031853
#> 6    sand     Species        40 148.398  62.50000 85.322493
dv_summary(prep, by = "habitat")
#>      community habitat n_stomachs n_records n_taxa records_per_stomach
#> 1 Benthic grab     mud         14        62      5                4.43
#> 2 Benthic grab    sand         14        64      5                4.57
#>   total_weight n_examined n_empty pct_vacuity
#> 1      154.664         15       1         6.7
#> 2      173.926         15       1         6.7
```

[`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
can also describe the order in which *recorded taxa* accumulate with
sampled grabs. The function name retains its diet heritage, but the
sampled units here are **grabs**. Rarefaction-like curves are
*descriptive*; completeness of a habitat survey needs design-based
analysis. The function uses **grabs represented in the long table**, so
known empty grabs held only in the separate inventory do not appear on
this curve’s x-axis.

``` r

acc <- dv_prey_accumulation(prep, rank = "family", permutations = 20, seed = 10)
head(acc)
#>   n_stomachs mean_richness sd_richness
#> 1          1          3.75   0.4442617
#> 2          2          4.00   0.0000000
#> 3          3          4.00   0.0000000
#> 4          4          4.00   0.0000000
#> 5          5          4.00   0.0000000
#> 6          6          4.00   0.0000000
```

## Export a grab × taxon matrix

``` r

m <- dv_matrix(prep, rank = "family", currency = "weight",
               include_empty = TRUE)
stopifnot(nrow(m) == nrow(frame))
c(grabs = nrow(m), taxonomic_categories = ncol(m))
#>                grabs taxonomic_categories 
#>                   30                    5
head(rowSums(m))
#>    G02    G03    G04    G05    G06    G07 
#> 12.236 10.033  9.543 12.457 14.262 15.753
utils::write.csv(m, file.path(tempdir(), "benthic_grab_wet_g.csv"))
```

For further analysis, examine differences in area, spatial
autocorrelation, replicate grabs, mesh size, wet-weight measurement
error and zero inflation. The exported values are raw **grams per
grab**, not a calibrated biomass surface for the habitat.

``` r

dv_build_html(prep,
  output = file.path(getwd(), "benthic_grabs_demo.html"),
  strata = "habitat", currency = "numbers",
  bands = c("occurrence", "weight"),
  title = "Benthic community composition (simulated; not a diet)")
```

## Reporting summary

Include sample-frame coverage, gear and grab area, taxonomic version,
units, preprocessing, empty vs failed samples, number of individuals,
mass measurement, unidentified share, replication and uncertainty. Do
**not** turn a nice sunburst into a claim about predator feeding,
ecosystem change or habitat preference: those conclusions require
additional data and inference. For the equivalent *catch composition*
workflow, see [the survey catch
case](https://sosthenea.github.io/DietView/articles/case-study-survey-catch.md).
