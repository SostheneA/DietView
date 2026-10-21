# Getting started with DietView

Stomach contents are rarely identified to a single depth. A shrimp may
be named to species, a fish fragment only to “Pisces”, and a bolus of
digested tissue to nothing at all. DietView keeps every one of those
records, attaches a taxonomic lineage to it, and lets you look at the
diet at all ranks at once, with the material that could not be
identified below a given rank kept in view.

``` r

library(DietView)
```

This vignette runs one complete analysis on real data: the public
extract of the ICES Stomach Content Database that ships with the package
as `ices_diet` (ICES Stomach Content Database, ICES, Copenhagen; extract
distributed with the R package stomachr, Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)).
It holds 9,639 prey records from 4,231 stomachs of 22 predator species,
sampled in the North Sea, the Skagerrak-Kattegat and the Baltic Sea in
2020-2024. A small invented table (`inst/extdata/dietview_example.csv`)
is also installed, for trying the mechanics on 24 rows. The vignette “A
known diet” uses a simulated survey, where the true diet is known, to
show what keeping unidentified records changes.

## 1. One row per prey record

``` r

head(ices_diet[ices_diet$predator_common == "Atlantic cod",
               c("stomach_id", "prey_name", "item_type", "digestion_label",
                 "prey_count", "prey_weight_g")])
#>    stomach_id    prey_name item_type digestion_label prey_count prey_weight_g
#> 18    S308644      Pagurus      prey      1 affected          1          0.40
#> 19    S308645      Pagurus      prey      1 affected          1          0.98
#> 20    S308645      Gadidae      prey      0 pristine          1         13.80
#> 21    S308646 Aphia minuta      prey      1 affected          1          0.11
#> 22    S308646 Aphia minuta      prey      1 affected          1          0.25
#> 23    S308646 Aphia minuta      prey      1 affected          1          0.27
table(ices_diet$item_type)
#> 
#>     non_food         prey unidentified 
#>           67         8019         1553
```

Each row is one prey record: a prey taxon found in one stomach, with its
WoRMS AphiaID, a count, a wet weight in grams and an ICES digestion code
(0, 1 or 2). The same taxon can appear in several records of one
stomach, as `Aphia minuta` does above, for example when prey were
measured one by one. The readable labels in `digestion_label` are
inferred from the older ICES format, so check them against the ICES
vocabulary before you rely on them. There are no taxonomy columns:
DietView adds them in step 3.

Real data need a decision before any figure: what counts as prey? The 67
non-food records (sand, stones, plastic, wood) are not diet. Nematodes
are mostly parasites of the fish, not food, and there are many of them.
We drop both, and say so when we report:

``` r

# drop non-food items and nematodes (mostly parasites, not prey)
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
```

That removes 1,042 nematode records, 827 of them from Atlantic mackerel,
whose record count falls from 2,423 to 1,593. A choice like this changes
the result more than any setting in the package.

## 2. Say which column is which

``` r

spec <- dv_spec(
  predator       = "predator_common",
  predator_latin = "predator_latin",
  stomach        = "stomach_id",
  prey_id        = "prey_aphia_id",   # WoRMS AphiaID, used first when present
  prey_name      = "prey_name",       # scientific name, used when there is no ID
  weight         = "prey_weight_g",
  count          = "prey_count",
  digestion      = "digestion_label",
  covariates     = c("region", "year", "quarter")
)
dv_validate(dat, spec)
#> 8530 records from 4222 stomachs of 22 predator(s); 2305 stomach(s) hold a single record; 531 record(s) lack a weight.
```

The specification changes nothing in your table. It records which column
plays which role, so the original data never have to be renamed, and it
can be saved next to your results.
[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
stops if a declared column is missing or a weight is negative, warns
about records with no prey key, weights that are not numbers and stomach
IDs shared between predators, and ends with a one-line description of
the sample. Here it notes that 531 records have no weight; they count in
the record shares but add nothing to the weight shares.

## 3. Attach the taxonomy

The package ships a frozen WoRMS lineage for every AphiaID in the data:
one row per AphiaID, one column per rank.

``` r

ices_lineage[ices_lineage$scientific_name %in%
               c("Crangon crangon", "Gobiidae", "Crustacea", "Pisces"),
             c("prey_aphia_id", "scientific_name", "worms_rank",
               "phylum", "class", "order", "family", "species")]
#>    prey_aphia_id scientific_name worms_rank     phylum        class       order
#> 48        107552 Crangon crangon    Species Arthropoda Malacostraca    Decapoda
#> 77          1066       Crustacea  Subphylum Arthropoda         <NA>        <NA>
#> 79        125537        Gobiidae     Family   Chordata    Teleostei Gobiiformes
#> 81         11676          Pisces Superclass   Chordata         <NA>        <NA>
#>         family         species
#> 48 Crangonidae Crangon crangon
#> 77        <NA>            <NA>
#> 79    Gobiidae            <NA>
#> 81        <NA>            <NA>
```

Look at how incomplete identifications are stored. `Gobiidae` stops at
family. `Crustacea` (a subphylum) and `Pisces` (a superclass) have a
phylum and nothing below it, because they are coarser than a class.
Those empty cells are not errors. They record where identification
stopped, and DietView keeps them. The “Unidentified material” records
have no AphiaID at all, so they get no lineage.

``` r

prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 8530 
#>   stomachs  : 4222 
#>   predators : 22 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: region, year, quarter 
#>   source    : table
```

With your own data you would normally query the World Register of Marine
Species once, read the matching report, and save the result as a lineage
table for every later run (the vignette on WoRMS shows how):

``` r

prep_online <- dv_prepare(dat, spec, taxonomy = "worms")   # needs 'worrms' and an internet connection
dv_taxonomy_report(prep_online)                            # doubtful and unresolved matches
```

Saving the lineage fixes the taxonomic snapshot your figures were made
from. Note the date and the `worrms` version alongside it, because WoRMS
changes.

## 4. Count the diet at every rank

``` r

tree <- dv_tree(prep)
cls  <- dv_rank_table(tree, "Class")
head(cls, 8)
#>           label value_item value_occ   pct_occ    value_w     pct_w
#> 23 Malacostraca         92      2085 24.443142  2948.8905 13.466316
#> 29    Teleostei         64      1614 18.921454 14366.4605 65.605452
#> 47           NA          1      1553 18.206331  1115.2120  5.092694
#> 20   Polychaeta         30       758  8.886284   584.2752  2.668134
#> 30           NA          1       713  8.358734  1328.6695  6.067463
#> 25           NA          1       662  7.760844   501.2407  2.288951
#> 36  Ophiuroidea          4       493  5.779601   526.9670  2.406432
#> 38     Bivalvia         12       317  3.716295   231.8770  1.058883
```

`value_occ` is the number of prey records assigned to each class, and
`pct_occ` its share of all records. `value_w` and `pct_w` do the same
for weight. Every record appears once in every ring of the tree: under
the taxon it was identified to at that rank or, if identification
stopped earlier, in an `NA` node below the last rank it reached. The
denominator is therefore the same at every rank, here all 8,530 records
or 21,898 g, and each ring adds up to 100%.

There are several `NA` rows because each sits under a different parent.
The tree says which:

``` r

na_cls <- tree[tree$rank == "Class" & tree$label == "NA", c("parent", "value_occ", "pct_occ")]
head(na_cls[order(-na_cls$value_occ), ], 3)
#>                 parent value_occ   pct_occ
#> 47               NA|NA      1553 18.206331
#> 30   Animalia|Chordata       713  8.358734
#> 25 Animalia|Arthropoda       662  7.760844
```

The largest, 1,553 records, is the unidentified material, with no
kingdom at all. The next two are records named only to a phylum or
something like it: 713 fish recorded as “Pisces”, “Gnathostomata” or
another name above class, and 662 arthropods recorded as “Crustacea” or
“Arthropoda”.

The two currencies tell different stories. Malacostraca (shrimps, crabs,
amphipods and their kin) make up 24.4% of the records but 13.5% of the
weight; bony fish (Teleostei) make up 18.9% of the records and 65.6% of
the weight. Records tell you how often a kind of prey turns up; weight
tells you how much it contributes. Report both, or say which one you
chose.

A note on names: `pct_occ` is a share of records. It is not the
frequency of occurrence (%FO) of the diet literature, which is the
proportion of stomachs containing a prey and does not add up across
prey.
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
gives %FO. Take cod alone, prepared the same way:

``` r

cod <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)
cls_cod <- dv_rank_table(dv_tree(prep_cod), "Class")
fo_cod  <- dv_fo_table(prep_cod, rank = "class")
head(fo_cod, 4)
#>    rank        taxon n_stomachs n_total pct_fo
#> 1 class Malacostraca        618     991  62.36
#> 2 class    Teleostei        332     991  33.50
#> 3 class           NA        323     991  32.59
#> 4 class   Polychaeta        136     991  13.72
```

Malacostraca are 43.4% of cod’s prey records but turn up in 62.4% of its
991 stomachs; fish are 27.1% of the records and are found in 33.5% of
the stomachs. The two measures answer different questions (“what share
of the records?” and “how many fish ate it?”), and the gap between them
grows when a stomach holds several records of the same prey.

## 5. How much was identified?

``` r

na_share <- sapply(prep$ranks, function(r) {
  tb <- dv_rank_table(tree, tools::toTitleCase(r))
  round(sum(tb$pct_occ[tb$label == "NA"]), 1)
})
na_share
#> kingdom  phylum   class   order  family   genus species 
#>    18.2    18.2    35.7    52.0    64.2    76.3    81.6
```

18.2% of the records are unidentified even at kingdom: that is the
unidentified material. The share nearly doubles at class (35.7%), where
“Pisces” and “Crustacea” stop, and reaches 81.6% at species. A statement
about species would rest on fewer than one record in five, and digestion
does not remove prey at random, so that fifth is not a random sample.
This is why DietView keeps the unidentified nodes: they show how far a
fine-rank statement can be trusted.

## 6. Draw it

``` r

dv_sunburst(dv_tree(prep_cod), mode = "occurrence",
            title = "Atlantic cod, share of prey records")
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
sp <- dg[dg$finest_rank == "Species", c("digestion", "n_records", "p_records")]
sp$p_records <- round(sp$p_records, 1)
sp
#>             digestion n_records p_records
#> 6          0 pristine       219      39.0
#> 13         1 affected      1093      31.3
#> 20 2 skeletal remains       126       5.7
#> 27       not recorded       128       5.6
```

For each digestion stage, the diagnostic gives the share of records
whose deepest identified rank is species, genus, and so on, or none at
all. The rows above are the species share: 39.0% of the records at stage
0, 31.3% at stage 1 and 5.7% at stage 2. The digestion vignette reads
the whole table, predator by predator.

## 8. Before you report

- Say what you removed before the analysis (here non-food items and
  nematodes) and why.
- State the currency of every percentage: records, numbers or weight.
- Report the unidentified share at the rank you discuss (step 5).
- Give the taxonomic source and its date, or archive the lineage table.
- If you aggregated rare prey
  ([`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)),
  give the threshold.
- Archive the specification and the code with the figures.
- Acknowledge the data source: here “ICES Stomach Content Database,
  ICES, Copenhagen”.
- Cite the package and the version you used. `citation("DietView")`
  gives the reference, “DietView: An R package for interactive,
  hierarchical visualization of predator stomach-content data”.

## 9. Share it

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet.html"),
              strata = c("region", "quarter"), length_col = "length_cm")
run_dietview(prep)   # interactive exploration, needs 'shiny'
```

The HTML file opens in any browser and needs neither R nor an internet
connection. It is a snapshot: it shows the data as they were when you
built it. The dashboard vignette builds one for the main predators, with
length classes.
