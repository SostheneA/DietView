# Reading the rings: denominators and unidentified prey

A DietView sunburst shows the diet at seven ranks at once, from kingdom
at the center to species at the edge. This article explains what a
percentage in any ring is a percentage of, and why prey that could not
be identified to a given rank stay in the figure instead of being
dropped. It uses the Atlantic cod records of the public ICES stomach
data that ship with the package (ICES Stomach Content Database, ICES,
Copenhagen; extract distributed with the R package stomachr, Lindmark
2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)).

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

cod  <- dat[dat$predator_common == "Atlantic cod", ]
prep <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
tree <- dv_build_tree(prep$data, prep$ranks, weight_col = spec$weight)
```

The cod data hold 2,304 prey records from 991 stomachs.

## One record, one place in every ring

[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
gives every record one place at every rank: the taxon it was identified
to at that rank or, if identification stopped earlier, an unidentified
node (`NA` in the tables) below the last rank it reached. Three cod prey
records show the range:

``` r

ex <- match(c("Crangon crangon", "Brachyura", "Pisces"), prep$data$prey_name)
prep$data[ex, c("prey_name", prep$ranks)]
#>            prey_name  kingdom     phylum        class    order      family
#> 26   Crangon crangon Animalia Arthropoda Malacostraca Decapoda Crangonidae
#> 3736       Brachyura Animalia Arthropoda Malacostraca Decapoda        <NA>
#> 3722          Pisces Animalia   Chordata         <NA>     <NA>        <NA>
#>        genus         species
#> 26   Crangon Crangon crangon
#> 3736    <NA>            <NA>
#> 3722    <NA>            <NA>
```

A brown shrimp (*Crangon crangon*) sits under Decapoda at order and
under *Crangon* at genus. A crab named only “Brachyura” sits under
Decapoda at order and in the unidentified node below Decapoda at family,
genus and species. A fish named only “Pisces” sits under Chordata at
phylum and in the unidentified node below Chordata from class outward.

So every ring holds the same records and the same weight:

``` r

rings <- unique(tree$rank)
data.frame(
  rank      = rings,
  records   = sapply(rings, function(r) sum(tree$value_occ[tree$rank == r])),
  weight_g  = sapply(rings, function(r) round(sum(tree$value_w[tree$rank == r]), 1)),
  pct_total = sapply(rings, function(r) round(sum(tree$pct_occ[tree$rank == r]), 1)),
  row.names = NULL
)
#>      rank records weight_g pct_total
#> 1 Kingdom    2304  10226.6       100
#> 2  Phylum    2304  10226.6       100
#> 3   Class    2304  10226.6       100
#> 4   Order    2304  10226.6       100
#> 5  Family    2304  10226.6       100
#> 6   Genus    2304  10226.6       100
#> 7 Species    2304  10226.6       100
```

Each percentage in the tree (`pct_occ` for records, `pct_w` for weight)
is a node’s value divided by that common total, and each ring adds up to
100%. The weight total is lower than it would be with every record
weighed: the 95 cod records without a weight count in the records
currency and add nothing to the weight one.

Because no record is lost between rings, a node’s value is also the sum
of its children’s values, which is what lets the rings nest:

``` r

kids <- tapply(tree$value_occ, tree$parent, sum)
parents <- tree[tree$id %in% names(kids), ]
all.equal(parents$value_occ, as.numeric(kids[parents$id]))
#> [1] TRUE
all.equal(parents$value_w, as.numeric(tapply(tree$value_w, tree$parent, sum)[parents$id]))
#> [1] TRUE
```

Both checks hold for the 282 nodes that have children, in records and in
weight.

## What dropping the unidentified records would do

The usual alternative is to drop, at each rank, the records that were
not identified to that rank, and to compute shares among the rest. Each
ring then has its own total, and the rings stop agreeing with each
other:

``` r

id_only <- function(r) tree[tree$rank == r & tree$label != "NA", ]
share_in <- function(r, pattern) {
  x <- id_only(r)
  100 * sum(x$value_occ[grepl(pattern, x$id, fixed = TRUE)]) / sum(x$value_occ)
}
mal <- c(class  = share_in("Class",  "|Malacostraca"),
         order  = share_in("Order",  "|Malacostraca|"),
         family = share_in("Family", "|Malacostraca|"),
         genus  = share_in("Genus",  "|Malacostraca|"))
round(mal, 1)
#>  class  order family  genus 
#>   53.1   56.5   47.5   51.7
```

Malacostraca would be 53.1% of the identified records at class, its
orders together 56.5% of the identified records at order, its families
47.5% at family and its genera 51.7% at genus. Nothing about the diet
changed between the rings; only the set of records did. Each ring drops
a different set of records (at family, the crabs named only “Brachyura”
and the shrimps named only “Caridea”; at genus, also the swimming crabs
named only Polybiidae), so the crustacean share swings with the
identification habits of the people who read the stomachs. With the
unidentified records kept, Malacostraca and everything below it hold the
same 999 records in every ring: 43.4% of the cod’s prey records.

## How much was not identified, and where

[`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
lists one ring. The unidentified records do not form one `NA` row: there
is one per parent, so you can tell what kind of prey stopped being
identified at that rank. At order:

``` r

ord <- dv_rank_table(tree, "Order")
na_rows <- tree[tree$rank == "Order" & tree$label == "NA",
                c("parent", "value_occ", "pct_occ")]
na_rows$pct_occ <- round(na_rows$pct_occ, 2)
na_rows[order(-na_rows$value_occ), ]
#>                                parent value_occ pct_occ
#> 68                           NA|NA|NA       192    8.33
#> 42               Animalia|Chordata|NA       153    6.64
#> 40             Animalia|Arthropoda|NA        68    2.95
#> 33       Animalia|Annelida|Polychaeta        44    1.91
#> 55 Animalia|Echinodermata|Ophiuroidea        22    0.95
#> 60         Animalia|Mollusca|Bivalvia        21    0.91
#> 64       Animalia|Mollusca|Gastropoda        18    0.78
#> 53          Animalia|Echinodermata|NA         5    0.22
#> 62      Animalia|Mollusca|Cephalopoda         5    0.22
#> 65               Animalia|Mollusca|NA         3    0.13
#> 28         Animalia|Annelida|Gephyrea         2    0.09
#> 29               Animalia|Annelida|NA         2    0.09
#> 41           Animalia|Chordata|Myxini         1    0.04
#> 66 Animalia|Platyhelminthes|Trematoda         1    0.04
sum(ord$pct_occ[ord$label == "NA"])
#> [1] 23.30729
```

Here 23.3% of the records are unidentified at order. The largest parts
are the material placed nowhere (parent `NA|NA|NA`), the fish not
identified beyond Chordata (“Pisces” and the like), and the crustaceans
named only “Crustacea” (parent `Animalia|Arthropoda|NA`). Report the
total next to any statement made at that rank: an order-level
description of this diet rests on the remaining 76.7%. The per-parent
rows say what the gap is made of, which matters as much as its size: a
gap made of fish and a gap made of worms bias a description in different
directions.

The share rises toward the edge of the sunburst:

``` r

sapply(rings, function(r) round(sum(tree$pct_occ[tree$rank == r & tree$label == "NA"]), 1))
#> Kingdom  Phylum   Class   Order  Family   Genus Species 
#>     8.3     8.3    18.4    23.3    39.4    52.5    60.9
```

## An unidentified node with named children

Most `NA` nodes have only `NA` below them. A few do not, because WoRMS
gives no taxon at one rank to some groups. In the ICES lineage, several
polychaete families have no order, and Priapulida have no class:

``` r

kid_named <- tapply(tree$label != "NA", tree$parent, any)
na_with_kids <- tree[tree$label == "NA" & tree$id %in% names(kid_named)[kid_named], ]
na_with_kids[, c("id", "rank", "value_occ")]
#>                                 id  rank value_occ
#> 26          Animalia|Priapulida|NA Class         1
#> 33 Animalia|Annelida|Polychaeta|NA Order        44
tree[tree$parent %in% na_with_kids$id & tree$label != "NA", c("parent", "label", "value_occ")]
#>                             parent          label value_occ
#> 67          Animalia|Priapulida|NA Priapulomorpha         1
#> 72 Animalia|Annelida|Polychaeta|NA   Arenicolidae         1
```

Such a node mixes two things. The 44 cod records in the unidentified
order node under Polychaeta are 43 polychaetes not identified beyond
class and one lugworm (Arenicolidae), a family to which WoRMS gives no
order: identified to family, it still appears unidentified at order. The
effect is one record here, but on another predator or survey it can be
large. Before you report an unidentified share at that rank, check these
rows; the article “Adapting DietView to your own survey” comes back to
it.

## The figures

Records first, then weight. In cod the two currencies rank prey very
differently, so look at both before choosing one to report.

``` r

dv_sunburst(tree, mode = "occurrence", title = "Atlantic cod",
            subtitle = "share of prey records")
```

``` r

dv_sunburst(tree, mode = "weight", title = "Atlantic cod",
            subtitle = "share of prey weight")
```

White wedges with gray edges are records not identified at that rank.
Hovering over a wedge shows its count and its share of the ring.

## Colors

[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
gives each taxon name one color and unidentified nodes white. Build it
once from all the records and pass it to every figure you want to
compare, so the same taxon has the same color everywhere:

``` r

pal <- dv_palette(tree$label)
length(pal)
#> [1] 260
head(pal)
#>      Animalia      Annelida    Arthropoda      Chordata Echinodermata 
#>     "#1f77b4"     "#aec7e8"     "#ff7f0e"     "#ffbb78"     "#2ca02c" 
#>      Mollusca 
#>     "#98df8a"
```

The palette has 20 colors and reuses them when there are more taxa. The
cod tree alone has 259 taxon names, so every color stands for about 13
of them. Check the hover labels before you read a color as a taxon.

[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
is the better choice at this size. It gives one hue to each phylum (the
second rank) and lighter tints of that hue to its descendants, and keeps
unidentified nodes white. Its colors are keyed by node, so build it from
the pooled tree and pass it to every panel in the same way:

``` r

pal_tree <- dv_palette_tree(tree)
dv_sunburst(tree, mode = "occurrence", colors = pal_tree, title = "Atlantic cod",
            subtitle = "share of prey records, colors by phylum")
```
