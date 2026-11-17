# Complete case study: fishery survey catch-composition data

## Why use DietView for survey catches?

Survey catches provide a different application of DietView’s
compositional tools. This simulated example starts with a haul-by-taxon
mass table, attaches a checked classification and produces a
hierarchical figure, a haul-occurrence table, a sample matrix and an
optional HTML dashboard. These outputs describe recorded catches, rather
than predator diet.

The question is how the recorded catch mass is distributed among taxa
and how much of the catch has only a coarse identification.

**Unit:** one haul. **Quantity:** catch mass in kg. **Pseudo-predator
role:** a constant label `"Survey catch"` required by the DietView API;
it is not an organism. **Stratum:** survey region. The output is a
description of captured material, not an estimate of fish abundance or
feeding.

## Construct and inspect the sample frame

``` r

library(DietView)
set.seed(640)
hauls <- data.frame(haul_id = sprintf("H%02d", 1:24),
                    region = rep(c("North", "South"), each = 12),
                    vessel = rep(c("V1", "V2"), 12))
hauls$assemblage <- "Survey catch"
# Use one haul as a known zero-catch sample, retained in the inventory.
make_w <- function(n, rate) round(stats::rgamma(n, shape = 2, rate = rate), 2)
wide <- data.frame(
  haul_id = hauls$haul_id, region = hauls$region,
  `Gadus morhua` = make_w(24, 0.22),
  `Clupea harengus` = make_w(24, 0.15),
  `Crangon crangon` = make_w(24, 0.45),
  `Unidentified fish` = make_w(24, 1.1),
  check.names = FALSE
)
wide[1, setdiff(names(wide), c("haul_id", "region"))] <- 0
hauls$empty <- rowSums(wide[setdiff(names(wide), c("haul_id", "region"))]) == 0
head(wide)
#>   haul_id region Gadus morhua Clupea harengus Crangon crangon Unidentified fish
#> 1     H01  North         0.00            0.00            0.00              0.00
#> 2     H02  North        12.04            9.10            5.51              4.00
#> 3     H03  North         9.00           15.14            6.50              1.90
#> 4     H04  North        20.69           15.46            2.30              0.40
#> 5     H05  North         4.75            4.03            4.61              4.43
#> 6     H06  North        12.19            8.44            6.87              3.01
```

The sample-frame table holds **all** 24 hauls. The wide matrix contains
one mass value per haul and taxon. In a real survey, add tow duration,
swept area, gear, vessel, habitat and sampling strata; retain reasons
for missing values rather than converting all missing measurements to
zero.

``` r

taxa <- setdiff(names(wide), c("haul_id", "region"))
stopifnot(!anyDuplicated(hauls$haul_id))
stopifnot(all(is.finite(as.matrix(wide[taxa]))),
          all(as.matrix(wide[taxa]) >= 0))
c(hauls = nrow(hauls), zeros = sum(hauls$empty),
  total_kg = sum(as.matrix(wide[taxa])))
#>    hauls    zeros total_kg 
#>    24.00     1.00   744.61
```

## Convert wide data to the required long format

``` r

long <- dv_from_wide(wide, taxa_in = "columns",
                     id_cols = c("haul_id", "region"),
                     sample_col = "haul_id", value_col = "catch_kg",
                     taxon_col = "prey_name")
long$assemblage <- "Survey catch"
head(long[, c("haul_id", "region", "prey_name", "catch_kg")])
#>   haul_id region    prey_name catch_kg
#> 1     H02  North Gadus morhua    12.04
#> 2     H03  North Gadus morhua     9.00
#> 3     H04  North Gadus morhua    20.69
#> 4     H05  North Gadus morhua     4.75
#> 5     H06  North Gadus morhua    12.19
#> 6     H07  North Gadus morhua     5.75
stopifnot(isTRUE(all.equal(sum(long$catch_kg), sum(as.matrix(wide[taxa])))))
```

The variable name `prey_name` is inherited from DietView’s diet-focused
interface. **These taxa are catch components, not prey.** Zeros were
dropped as absent taxon–haul records; the zero-catch haul remains in
`hauls`.

## Attach a frozen taxonomy and retain coarse identifications

For a real survey, source this classification from a checked WoRMS/GBIF
release and archive its identifiers and date. Here it is explicitly
**illustrative**, with one deliberately unidentified fish category.

``` r

lineage <- data.frame(
  prey_name = c("Gadus morhua", "Clupea harengus", "Crangon crangon",
                "Unidentified fish"),
  kingdom = rep("Animalia", 4),
  phylum = c("Chordata", "Chordata", "Arthropoda", "Chordata"),
  class = c("Actinopteri", "Actinopteri", "Malacostraca", "Actinopteri"),
  order = c("Gadiformes", "Clupeiformes", "Decapoda", NA),
  family = c("Gadidae", "Clupeidae", "Crangonidae", NA),
  genus = c("Gadus", "Clupea", "Crangon", NA),
  species = c("Gadus morhua", "Clupea harengus", "Crangon crangon", NA)
)
spec <- dv_spec(predator = "assemblage", stomach = "haul_id",
                prey_name = "prey_name", weight = "catch_kg",
                weight_type = "mass", unit_label = "haul",
                covariates = "region")
prep <- dv_prepare(long, spec, taxonomy = "table", lineage = lineage,
                   stomachs = hauls, empty_col = "empty", verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 92 
#>   hauls     : 23 
#>   predators : 1 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: region 
#>   source    : table 
#>   examined  : 24 hauls, 1 empty
```

## Calculate mass composition and haul occurrence

``` r

tree <- dv_tree(prep)
phylum <- dv_rank_table(tree, "Phylum")
phylum[, c("label", "value_w", "pct_w", "pct_occ")]
#>        label value_w    pct_w pct_occ
#> 3   Chordata  643.17 86.37676      75
#> 2 Arthropoda  101.44 13.62324      25
fo <- dv_fo_table(prep, rank = "class", denominator = "examined")
fo[, c("taxon", "n_stomachs", "n_total", "pct_fo")]
#>          taxon n_stomachs n_total pct_fo
#> 1  Actinopteri         23      24  95.83
#> 2 Malacostraca         23      24  95.83
```

`value_w` is **kg of recorded catch** and `pct_w` the percentage of
total recorded catch mass. `pct_occ` is the proportion of non-zero
taxon–haul records; it is *not* the relative number of fish. `pct_fo` is
the percentage of examined **hauls with recorded catches** of a category
(a presence frequency), not the diet frequency of occurrence of any
predator.

A large mass share can reflect a few large hauls. It must not be
interpreted as stock biomass, population abundance, CPUE or habitat
preference without sampling effort, catchability and survey-design
adjustments.

``` r

dv_sunburst(tree, mode = "weight", title = "Simulated survey catch",
            subtitle = "Share of recorded catch mass (kg); not predator diet")
```

White wedges below the classified fish lineage show the mass not
identified to order/family/species. Dropping them would spuriously
inflate the shares of precisely identified species.

## Export a haul-by-taxon matrix with the zero-catch haul

``` r

m <- dv_matrix(prep, rank = "family", currency = "weight",
               include_empty = TRUE)
c(hauls = nrow(m), categories = ncol(m))
#>      hauls categories 
#>         24          4
stopifnot(nrow(m) == nrow(hauls))
head(rowSums(m))
#>   H02   H03   H04   H05   H06   H07 
#> 30.65 32.54 38.85 17.82 30.51 18.52
utils::write.csv(m, file.path(tempdir(), "survey_catch_kg_by_haul.csv"))
```

For downstream multivariate work, document whether the matrix contains
raw kg, kg/hour, kg/swept km², or another effort-standardized quantity.
DietView exports raw values; it does not infer survey design or apply
catchability corrections.

## Optional HTML output and reporting notes

``` r

dv_build_html(prep,
  output = file.path(getwd(), "survey_catch_demo.html"),
  bands = c("occurrence", "weight"), strata = "region",
  title = "Simulated catch composition (not predator diet)")
```

A scientific report should state the target population, sample
selection, tow/gears and effort, units and detection limits, treatment
of zero catches, taxonomic authority, reporting rank, uncertainty, and
whether estimates are weighted to the survey design. This vignette is a
demonstration of a **hierarchical composition tool**, not a replacement
for fisheries stock assessment or ecosystem-survey estimators.
