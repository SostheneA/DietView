# Getting started with DietView

Stomach contents are rarely identified to a single depth. A shrimp may
be named to species, a fish fragment only to “Teleostei”, and a bolus of
digested tissue to nothing at all. DietView keeps every one of those
records, attaches a taxonomic lineage to it, and lets you look at the
diet at all ranks at once, with the material that could not be
identified below a given rank kept in view.

This vignette runs one complete analysis on the example table that ships
with the package. The table is invented: 24 prey records from 11
stomachs of three predators. That is enough to show every step and far
too little to say anything about what these fish eat, so read the
numbers below as a demonstration of the mechanics only. The vignette “A
known diet” uses a larger simulated survey to show what keeping
unidentified records changes.

``` r

library(DietView)
```

## 1. One row per prey record

``` r

dat <- read.csv(system.file("extdata", "dietview_example.csv", package = "DietView"),
                na.strings = c("NA", ""))
head(dat[, c("predator_species_common_name", "stomach_id", "verified_name",
             "prey_weight", "digestion_level_id")])
#>   predator_species_common_name stomach_id      verified_name prey_weight
#> 1                 Atlantic cod      GM001  Pandalus borealis        12.3
#> 2                 Atlantic cod      GM001   Ammodytes dubius         5.1
#> 3                 Atlantic cod      GM001           Decapoda         2.0
#> 4                 Atlantic cod      GM002 Themisto libellula         0.8
#> 5                 Atlantic cod      GM002          Teleostei         8.0
#> 6                 Atlantic cod      GM003  Pandalus borealis         9.0
#>   digestion_level_id
#> 1                  2
#> 2                  3
#> 3                  4
#> 4                  2
#> 5                  4
#> 6                  1
```

Each row is one prey taxon found in one stomach, with its wet weight in
grams and a digestion score from 1 (fresh) to 5 (unrecognizable). There
are no taxonomy columns. DietView adds them in step 3.

## 2. Say which column is which

``` r

spec <- dv_spec(
  predator   = "predator_species_common_name",
  stomach    = "stomach_id",
  prey_id    = "aphia_id",        # WoRMS AphiaID, used first when present
  prey_name  = "verified_name",   # scientific name, used when there is no ID
  weight     = "prey_weight",
  digestion  = "digestion_level_id",
  covariates = c("period", "region")
)
dv_validate(dat, spec)
#> 24 records from 11 stomachs of 3 predator(s); 1 stomach(s) hold a single record; 0 record(s) lack a weight.
```

The specification changes nothing in your table. It records which column
plays which role, so the original data never have to be renamed, and it
can be saved next to your results.
[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
stops if a declared column is missing or a weight is negative, warns
about records with no prey key, weights that are not numbers and stomach
IDs shared between predators, and ends with a one-line description of
the sample.

## 3. Attach the taxonomy

The example ships with a lineage table: one row per prey name, one
column per rank.

``` r

lin <- read.csv(system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
                na.strings = c("NA", ""))
lin[lin$verified_name %in% c("Pandalus borealis", "Decapoda", "unidentified material"), ]
#>           verified_name  kingdom     phylum        class    order     family
#> 1     Pandalus borealis Animalia Arthropoda Malacostraca Decapoda Pandalidae
#> 3              Decapoda Animalia Arthropoda Malacostraca Decapoda       <NA>
#> 7 unidentified material     <NA>       <NA>         <NA>     <NA>       <NA>
#>      genus           species
#> 1 Pandalus Pandalus borealis
#> 3     <NA>              <NA>
#> 7     <NA>              <NA>
```

Look at how incomplete identifications are stored. `Decapoda` has an
order but no family, genus or species, and `unidentified material` has
nothing. Those empty cells are not errors. They record where
identification stopped, and DietView keeps them.

``` r

prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lin, verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 24 
#>   stomachs  : 11 
#>   predators : 3 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: period, region 
#>   source    : table
```

With your own data you would normally query the World Register of Marine
Species once, read the matching report, and save the result as a lineage
table for every later run:

``` r

prep_online <- dv_prepare(dat, spec, taxonomy = "worms")   # needs 'worrms' and an internet connection
dv_taxonomy_report(prep_online)                            # fuzzy and unresolved matches
```

Saving the lineage fixes the taxonomic snapshot your figures were made
from. Note the date and the `worrms` version alongside it, because WoRMS
changes.

## 4. Count the diet at every rank

``` r

tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
cls  <- dv_rank_table(tree, "Class")
cls
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca          7        11 45.833333 39.7600 51.504725584
#> 9      Copepoda          2         4 16.666667  0.0048  0.006217874
#> 11    Teleostei          3         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta          1         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia          1         2  8.333333  0.0290  0.037566324
#> 13           NA          1         2  8.333333  1.6000  2.072624772
```

`value_occ` is the number of prey records assigned to each class, and
`pct_occ` its share of all records. `value_w` and `pct_w` do the same
for weight. Every record appears once in every ring of the tree: under
the taxon it was identified to at that rank or, if identification
stopped earlier, in an `NA` node below the last rank it reached. The
denominator is therefore the same at every rank, here all 24 records or
77.2 g, and each ring adds up to 100%.

The two currencies tell different stories. Malacostraca make up 45.8% of
the records, and fish (Teleostei) only 12.5%, yet the fish account for
45.5% of the weight. Records tell you how often a kind of prey turns up;
weight tells you how much it contributes. Report both, or say which one
you chose.

A note on names: `pct_occ` is a share of records. It is not the
frequency of occurrence (%FO) of the diet literature, which is the
proportion of stomachs containing a prey and does not add up across
prey.
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
gives %FO:

``` r

fo <- dv_fo_table(prep, rank = "class")
fo[fo$taxon == "Malacostraca", ]
#>    rank        taxon n_stomachs n_total pct_fo
#> 1 class Malacostraca          7      11  63.64
```

Malacostraca account for 11 of the 24 records but turn up in 7 of the 11
stomachs, because several stomachs hold more than one malacostracan.

## 5. How much was identified?

``` r

na_share <- sapply(prep$ranks, function(r) {
  tb <- dv_rank_table(tree, tools::toTitleCase(r))
  round(sum(tb$pct_occ[tb$label == "NA"]), 1)
})
na_share
#> kingdom  phylum   class   order  family   genus species 
#>     8.3     8.3     8.3    37.5    58.3    62.5    62.5
```

In this table 37.5% of the records are unidentified at order and 62.5%
at species. A statement about species would rest on fewer than half of
the records, and digestion does not remove prey at random, so that half
is not a random sample. This is why DietView keeps the unidentified
nodes: they show how far a fine-rank statement can be trusted.

## 6. Draw it

``` r

dv_sunburst(tree, mode = "occurrence", title = "All predators, share of prey records")
```

The figure is interactive, so it is drawn on the package website rather
than in this installed vignette. The center is the kingdom ring and each
ring outward is one rank finer. White wedges with gray edges are records
not identified at that rank. Hovering shows the count and the share.
When you compare panels, build one palette from the pooled data and pass
it to every panel (see the article on covariates).

## 7. Digestion

``` r

dg <- dv_digestion_diagnostic(prep)
dg[, c("digestion", "finest_rank", "n_records", "p_records")]
#>    digestion finest_rank n_records p_records
#> 1          1     Species         2 100.00000
#> 2          2       Class         3  33.33333
#> 3          2       Order         2  22.22222
#> 4          2     Species         4  44.44444
#> 5          3       Class         2  28.57143
#> 6          3       Order         2  28.57143
#> 7          3      Family         1  14.28571
#> 8          3     Species         2  28.57143
#> 9          4       Class         2  50.00000
#> 10         4       Order         1  25.00000
#> 11         4     Species         1  25.00000
#> 12         5  Unresolved         2 100.00000
```

For each digestion score, the table gives the share of records whose
deepest identified rank is species, genus, and so on, or none at all.
With 24 records, two of them at score 1 and two at score 5, it cannot
show a trend; it only shows the layout. The digestion vignette explains
how to read it on real data.

## 8. Before you report

- State the currency of every percentage: records, numbers or weight.
- Report the unidentified share at the rank you discuss (step 5).
- Give the taxonomic source and its date, or archive the lineage table.
- If you aggregated rare prey
  ([`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)),
  give the threshold.
- Archive the specification and the code with the figures.
- Cite the package and the version you used. `citation("DietView")`
  gives the reference, “DietView: An R package for interactive,
  hierarchical visualization of predator stomach-content data”.

## 9. Share it

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet.html"),
              strata = c("period", "region"))
run_dietview(prep)   # interactive exploration, needs 'shiny'
```

The HTML file opens in any browser and needs neither R nor an internet
connection. It is a snapshot: it shows the data as they were when you
built it.
