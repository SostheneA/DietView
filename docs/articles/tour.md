# A guided tour of the main functions

This article goes through the package one function at a time. For each
function it says why you would use it, what it does, what it returns,
and which arguments change the answer. It ends with three short
applications that show how much a result moves when you change the
currency or the rank you report at.

``` r

library(DietView)
```

Everything runs offline on the public ICES stomach data that ship with
the package
([`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)):
9,639 prey records from 4,231 stomachs of 22 fish predators caught in
the North Sea, the Skagerrak-Kattegat and the Baltic Sea, 2020-2024.
Source: ICES Stomach Content Database, ICES, Copenhagen; extract
distributed with the R package stomachr (Lindmark 2026). The package
also keeps a 24-record invented table
(`inst/extdata/dietview_example.csv`) for checking the mechanics on
something you can read in full.

## The pipeline

DietView is a short pipeline. Every step returns an object you can
print, inspect and save.

| Step | Function | Returns |
|----|----|----|
| Declare | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md) | `dietview_spec`: which column plays which role |
| Check | [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md) | the data, invisibly, with messages about it |
| Prepare | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md) | `dietview_prep`: data, taxonomy and matching log |
| Review | [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md) | the matches that need a look |
| Count | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md), [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md) | `dietview_tree`: one row per node, with records, weight and shares |
| Read | [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md) | the rows of one ring |
| Draw | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md) | a plotly figure |
| Share | [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md), [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md), [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md) | an HTML file, a Shiny app, a deployed file |

Two helpers
([`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md),
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md))
build covariates,
[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
and
[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
set the colors,
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
relates identification depth to digestion, and
[`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
finds a photo and a description for a predator. The functions that
describe and aggregate the sample before any figure
([`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md),
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md),
[`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md),
…) have their own article, “Exploring and aggregating diet data”.

## The data, and what to keep

``` r

str(ices_diet[, c("stomach_id", "predator_common", "prey_aphia_id",
                  "prey_name", "item_type", "prey_count", "prey_weight_g",
                  "digestion_label", "region", "year", "quarter", "length_cm")],
    vec.len = 2, give.attr = FALSE)
#> 'data.frame':    9639 obs. of  12 variables:
#>  $ stomach_id     : chr  "S167767" "S167777" ...
#>  $ predator_common: chr  "Whiting" "Whiting" ...
#>  $ prey_aphia_id  : int  NA NA NA NA NA ...
#>  $ prey_name      : chr  "Unidentified material" "Unidentified material" ...
#>  $ item_type      : chr  "unidentified" "unidentified" ...
#>  $ prey_count     : int  1 1 1 1 1 ...
#>  $ prey_weight_g  : num  0.03 0.07 0.06 0.01 0.2 ...
#>  $ digestion_label: chr  "1 affected" "1 affected" ...
#>  $ region         : chr  "Baltic Sea" "Baltic Sea" ...
#>  $ year           : int  2020 2020 2020 2020 2020 ...
#>  $ quarter        : num  4 4 4 4 4 ...
#>  $ length_cm      : num  19 18 18 18 16 ...
table(ices_diet$item_type)
#> 
#>     non_food         prey unidentified 
#>           67         8019         1553
```

One row is one prey record: one prey taxon found in one stomach, with
the stomach and haul variables repeated on each row. There are no
`kingdom` to `species` columns; DietView adds them from the frozen WoRMS
lineage `ices_lineage`.

Two kinds of rows are not diet. The 67 non-food items (sand, stones,
plastic, wood) are flagged by `item_type`, and nematodes in fish
stomachs are mostly parasites rather than prey. The data keep both,
because deciding is the analyst’s job; here we drop them:

``` r

phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
nrow(dat)
#> [1] 8530
```

That removes 1042 nematode records and leaves 8,530 records. The 1,553
records of unidentified material stay: they are part of what the
predators ate.

## `dv_spec()`: declare your columns once

**Why.** Every survey names its columns differently. Instead of renaming
them before the analysis, which leaves published code working on a table
that no longer matches the archived data, you record which column plays
which role. The original table stays as it is, and the specification can
be printed, archived and compared between studies.

**What it does.** It stores the mapping and nothing else. Your data are
not touched.

``` r

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

str(spec)
#> List of 10
#>  $ predator      : chr "predator_common"
#>  $ stomach       : chr "stomach_id"
#>  $ prey_name     : chr "prey_name"
#>  $ prey_id       : chr "prey_aphia_id"
#>  $ weight        : chr "prey_weight_g"
#>  $ count         : chr "prey_count"
#>  $ digestion     : chr "digestion_label"
#>  $ covariates    : chr [1:3] "region" "year" "quarter"
#>  $ ranks         : chr [1:7] "kingdom" "phylum" "class" "order" ...
#>  $ predator_latin: chr "predator_latin"
#>  - attr(*, "class")= chr "dietview_spec"
```

**Arguments that matter.**

*`prey_id` is used before `prey_name`.* Give both when you have both.
The ID is used for the lookup, and the name lets DietView check that the
two agree. When a record has no ID, its name is used.

*`prey_name` must be the scientific name*, because it is sent to WoRMS,
which does not know common names. A common name either fails to match
or, with fuzzy matching, can match a wrong taxon. The predator, by
contrast, is never looked up: it is only a grouping and display label,
so a common name such as “Atlantic cod” is fine. `predator_latin` is
used for the species cards.

*The name does not have to be a species.* In the ICES data, “Crustacea”
(546 records), “Pisces” (434) and “Polychaeta” (444) are among the most
frequent prey names: they record the rank at which identification
stopped. Do not replace them with a guessed species; DietView shows such
records as unidentified below the rank they reached.

*`ranks` defaults to seven ranks*, kingdom to species. Shorten it if
your prey are never identified past family; the sunburst then has fewer
rings.

*`covariates` lists what you can later compare diets across.* Declaring
a column costs nothing.

*`count`* declares a column of individuals per record, for the numerical
share (%N). Build trees with `dv_tree(prep, "numbers")` when you want
%N, and note that records without a count then contribute nothing (see
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
below).

## `dv_validate()`: check the table before anything else

Run
[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
before anything else. It stops if a column you declared is missing, if
there is no prey key column or if a weight is negative. It warns if
weights are not numbers, if records have no prey key or if stomach IDs
repeat across predators, and it ends with a one-line description of the
sample: how many records, stomachs and predators, and how many records
lack a weight. It never changes your data.

``` r

dv_validate(dat, spec)
#> 8530 records from 4222 stomachs of 22 predator(s); 2305 stomach(s) hold a single record; 531 record(s) lack a weight.
```

No warning here: every record has a prey key (an AphiaID or, for
unidentified material, a name), and stomach IDs are unique across
predators. More than half the stomachs hold a single prey record, which
matters for every statistic that counts stomachs.

**What you get back.** The data, invisibly, with the counts in the
`dv_report` attribute. The information is in the messages and warnings.

**Arguments that matter.** With `strict_covariates = FALSE`, a declared
covariate missing from the data is dropped from the specification with a
warning instead of stopping.
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
takes the same argument.

## `dv_prepare()`: attach the taxonomy, and log how

**Why.** Here prey are placed in a taxonomic hierarchy taken from an
external authority or from a lineage table you supply, instead of being
grouped by hand. Two surveys prepared against the same authority can
then be compared without recoding.

**What it does.** It validates the table, looks up each distinct prey
key, joins the lineage back to every record, and leaves the ranks below
the last identified rank empty.

``` r

prep <- dv_prepare(
  dat, spec,
  taxonomy = "table",       # offline: use the frozen lineage supplied
  lineage  = ices_lineage,
  verbose  = FALSE
)

prep
#> <dietview_prep>
#>   records   : 8530 
#>   stomachs  : 4222 
#>   predators : 22 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: region, year, quarter 
#>   source    : table
```

**What you get back.** A `dietview_prep` list. Its main components are:

- `data`: your table plus one column per rank;
- `spec`: the specification;
- `ranks`: the ranks used;
- `taxonomy_log`: on the WoRMS path, one row per distinct prey with how
  it was matched.

``` r

ex <- match(c("Crangon crangon", "Ammodytidae", "Pisces", "Unidentified material"),
            prep$data$prey_name)
prep$data[ex, c("prey_name", prep$ranks)]
#>                 prey_name  kingdom     phylum        class       order
#> 26        Crangon crangon Animalia Arthropoda Malacostraca    Decapoda
#> 55            Ammodytidae Animalia   Chordata    Teleostei Perciformes
#> 179                Pisces Animalia   Chordata         <NA>        <NA>
#> 1   Unidentified material     <NA>       <NA>         <NA>        <NA>
#>          family   genus         species
#> 26  Crangonidae Crangon Crangon crangon
#> 55  Ammodytidae    <NA>            <NA>
#> 179        <NA>    <NA>            <NA>
#> 1          <NA>    <NA>            <NA>
```

The brown shrimp is resolved to species. Sandeels (Ammodytidae) stop at
family, “Pisces” (a WoRMS superclass) stops at phylum, and unidentified
material has no rank at all.

**Arguments that matter.**

*`taxonomy` chooses the source.*

| Value | Behavior | When to use |
|----|----|----|
| `"auto"` | use rank columns if present, else the lineage table if one is given, else WoRMS | quick exploration |
| `"columns"` | use rank columns already in the data | taxonomy resolved elsewhere |
| `"worms"` | query WoRMS online | first pass on a new dataset |
| `"table"` | join a lineage table you supply | reruns, offline work, non-marine prey |

*Resolve once, then freeze.* Run once with `taxonomy = "worms"`, read
the log, save the resulting lineage table, and use `taxonomy = "table"`
for every later run. Later runs are then offline and fast, and they use
one fixed taxonomic snapshot. `ices_lineage` is such a snapshot: 461
AphiaIDs with their lineage, joined on `prey_aphia_id`. Different
versions of an authority can return different lineages, so an archived
lineage table plays the same role for the taxonomy as a lockfile does
for package versions.

*`fuzzy = TRUE` has a cost.* It can match a misspelled name, and it can
also match a different taxon whose name is close. Every such match is
logged with `match_type = "fuzzy"`, and you need to read the log to
catch the wrong ones.

*The number of lookups depends on the number of distinct prey, not on
the number of records.* The 8,530 records here hold 252 distinct
AphiaIDs, so a WoRMS run needs that many lookups.

## `dv_taxonomy_report()`: read the log before you plot

**Why.** Fuzzy and unresolved matches are where a diet description most
often goes wrong without anyone noticing.

**What it does.** It returns the rows of the matching log that need a
look, largest number of records first.

``` r

prep_online <- dv_prepare(dat, spec, taxonomy = "worms")

dv_taxonomy_report(prep_online, which = "review")   # the matches to check
dv_taxonomy_report(prep_online, which = "all",      # the whole log, to archive
                   file = file.path(tempdir(), "taxonomy_log.csv"))
```

The log exists only on the WoRMS path. A `prep` built with
`taxonomy = "table"`, as everywhere else in this article, has no
matching history, because the matching was done when the table was
built, and this function stops with a message saying so. The review
therefore belongs to the one online run in the resolve-once-then-freeze
workflow, not to every rerun.

`which = "review"` (the default) returns fuzzy and unresolved matches,
unaccepted IDs that were replaced by their accepted ID, IDs that could
not be checked, names that differ from the name WoRMS holds for their
ID, and prey whose classification could not be retrieved. `"fuzzy"` and
`"unresolved"` return one of those groups; `"all"` returns the whole
log. Pass `file` to write it out.

An unresolved prey is not always an error. In the ICES data
“Unidentified material” has no AphiaID and no taxonomic name, so it
should not match anything; its records are unidentified at every rank.
The unresolved prey you did not expect are the ones to chase.

## `dv_build_tree()` and `dv_tree()`: count the diet at every rank

**Why.** This is where the shares at every rank are computed.

**What it does.** It counts at the finest rank and adds up toward the
kingdom. Each node carries three values: `value_item` (the number of
distinct prey items below it), `value_occ` (the number of prey records)
and `value_w` (the summed weight). Dividing by the total gives `pct_occ`
and `pct_w`. `dv_tree(prep)` is the short form that reads the columns
from the specification.

``` r

tree <- dv_build_tree(
  prep$data,
  ranks      = prep$ranks,
  weight_col = spec$weight
)

nrow(tree)
#> [1] 702
head(tree, 4)
#>          id     label parent    rank value_item value_occ   value_w     pct_occ
#> 1  Animalia  Animalia        Kingdom        237      6975 20782.912 81.77022274
#> 2 Chromista Chromista        Kingdom          1         1     0.000  0.01172333
#> 3   Plantae   Plantae        Kingdom          1         1     0.148  0.01172333
#> 4        NA        NA        Kingdom          1      1553  1115.212 18.20633060
#>          pct_w
#> 1 9.490663e+01
#> 2 0.000000e+00
#> 3 6.758524e-04
#> 4 5.092694e+00
```

**What you get back.** A `dietview_tree` data frame with `id`, `label`,
`parent`, `rank`, the three values and the two shares; here 702 nodes
over seven rings.

Every record has one place in every ring: under the taxon it was
identified to at that rank or, if identification stopped earlier, in an
unidentified node below the last rank it reached. Two properties follow,
and it is worth checking them once:

``` r

# 1. every ring holds all the records, so each sums to 100%
round(tapply(tree$pct_occ, tree$rank, sum), 6)
#>   Class  Family   Genus Kingdom   Order  Phylum Species 
#>     100     100     100     100     100     100     100

# 2. a parent's value equals the sum of its children's (largest gap: 0)
kid_sums <- tapply(tree$value_occ, tree$parent, sum)
parents  <- intersect(tree$id, names(kid_sums))
max(abs(tree$value_occ[match(parents, tree$id)] - kid_sums[parents]))
#> [1] 0
```

The first lets you read any ring on its own. The second is what lets the
rings nest in a sunburst. Because every ring holds the same records, the
denominator is the same at every rank: here all 8,530 records.

**Arguments that matter.**

*`weight_col = NULL` is allowed* and leaves the weight view empty. The
share of prey records still works. Use it when weights are too sparse to
trust; here 531 records (6.2%) have no weight.

*`count_col` changes what one record counts for.* Left `NULL`, each
record counts once and `pct_occ` is the share of prey records. Given a
column of counts, each record counts its number of individuals and
`pct_occ` becomes the numerical share (%N). `dv_tree(prep, "numbers")`
does this from the specification, and it warns about the records without
a count:

``` r

tree_n <- dv_tree(prep, "numbers")
#> Warning: 3468 record(s) have no count and contribute 0 to the numbers currency;
#> unidentified material usually has no count, so it will not appear in this view.
```

In the ICES data 3,468 records (41%) have no count, among them 1,516 of
the 1,553 records of unidentified material, so %N describes a smaller
and better-identified part of the diet than the share of records does.
Say in your methods which one you used.

*`value_occ` counts prey records, not stomachs.* This is the quantity
most likely to be misread. Its share is not the frequency of occurrence
(%FO) of the diet literature, which is the share of stomachs containing
a prey. %FO does not add up from children to parent: a stomach holding
two species of one genus counts once for the genus and once for each
species. A nested sunburst needs values that add up, so it cannot show
%FO. Use
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
for %FO, and report each quantity under its own name.

## `dv_rank_table()`: the numbers behind one ring

**Why.** A figure is for looking; a table is for reporting and checking.

**What it does.** It returns the rows of one rank, sorted by share of
prey records, with the unidentified rows included.

``` r

cls <- dv_rank_table(tree, "Class")
head(cls, 10)
#>           label value_item value_occ    pct_occ    value_w      pct_w
#> 23 Malacostraca         92      2085 24.4431419  2948.8905 13.4663157
#> 29    Teleostei         64      1614 18.9214537 14366.4605 65.6054516
#> 47           NA          1      1553 18.2063306  1115.2120  5.0926940
#> 20   Polychaeta         30       758  8.8862837   584.2752  2.6681338
#> 30           NA          1       713  8.3587339  1328.6695  6.0674627
#> 25           NA          1       662  7.7608441   501.2407  2.2889509
#> 36  Ophiuroidea          4       493  5.7796014   526.9670  2.4064318
#> 38     Bivalvia         12       317  3.7162954   231.8770  1.0588826
#> 40   Gastropoda          3        72  0.8440797    26.4690  0.1208725
#> 37           NA          1        67  0.7854631    26.1870  0.1195848
```

Rank labels are title case (`"Class"`, `"Family"`, `"Genus"`), built
from the specification’s `ranks`. The rows labeled `NA` are the records
unidentified at this rank, one row per parent. The tree says which
parent each one hangs from:

``` r

tree[tree$rank == "Class" & tree$label == "NA", c("parent", "value_occ", "pct_occ")]
#>                      parent value_occ     pct_occ
#> 21        Animalia|Annelida        23  0.26963658
#> 25      Animalia|Arthropoda       662  7.76084408
#> 26    Animalia|Chaetognatha         2  0.02344666
#> 30        Animalia|Chordata       713  8.35873388
#> 33        Animalia|Cnidaria         1  0.01172333
#> 37   Animalia|Echinodermata        67  0.78546307
#> 41        Animalia|Mollusca        10  0.11723329
#> 44 Animalia|Platyhelminthes         4  0.04689332
#> 45      Animalia|Priapulida         7  0.08206331
#> 47                    NA|NA      1553 18.20633060
#> 48      Plantae|Chlorophyta         1  0.01172333
```

The parent `NA|NA` is the material placed nowhere; `Animalia|Chordata`
holds the fish not identified to class, such as “Pisces”;
`Animalia|Arthropoda` holds mostly “Crustacea” and “Arthropoda”. Keep
these rows: dropping them would rescale the remaining shares to the
identified records only. At class, 35.7% of all records sit in such
rows.

## `dv_sunburst()`: the whole diet in one figure

**Why.** A taxonomy is a hierarchy, and a bar chart shows one rank at a
time. A sunburst shows every rank at once.

**What it does.** It draws the tree, with records unidentified at a rank
in white wedges with gray edges.

``` r

dv_sunburst(tree, mode = "occurrence", title = "22 predators pooled",
            subtitle = "share of prey records")
```

Pooling 22 predators is useful for seeing the whole dataset, not for
describing a diet. The rest of the article mostly uses one predator,
Atlantic cod:

``` r

cod      <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)
tree_cod <- dv_tree(prep_cod)

dv_sunburst(tree_cod, mode = "weight", title = "Atlantic cod",
            subtitle = "share of prey weight")
```

**Arguments that matter.**

*`mode` chooses what sizes the wedges:* `"count"` (the default: distinct
prey items), `"occurrence"` (prey records) or `"weight"`. Records and
weight rank prey very differently in cod (see Application 1), so look at
both.

*`colors` matters as soon as you compare panels.* Left `NULL`, each call
builds its own palette from its own labels, so two panels can give the
same taxon different colors. Build one palette from the pooled tree and
pass it to every panel:

``` r

colors <- dv_palette(tree$label)   # from the pooled tree: covers every taxon
length(colors)
#> [1] 403
colors["NA"]                       # unidentified is always white
#>        NA 
#> "#FFFFFF"
```

[`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
and
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
do this for you. You only need to do it when you draw panels yourself.

*`rotation = 90` puts the start angle at the top*, and the figure keeps
the node order from
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
instead of sorting wedges by size. Panels therefore start at the same
angle and list taxa in the same order.

That does not keep a taxon at the same angle in every panel. If a taxon
is absent from one stratum, the wedges after it move round to close the
gap. Use color, not position, to find a taxon across panels.

## `dv_palette()` and `dv_palette_tree()`: colors, and white for unidentified records

**Why.** Across panels, a taxon is recognized by its color, and
unidentified records need to look different from everything else.

**What it does.**
[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
gives each label a color from a 20-color palette and makes `"NA"` white.
The pooled ICES tree has 402 distinct taxon names, so each color is
shared by about 20 taxa: check the hover labels before you read a color
as a taxon.

[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
is the alternative for a survey of this size. It gives one hue to each
phylum and lighter tints of that hue to its descendants, so a color at
least tells you the phylum:

``` r

pal_tree <- dv_palette_tree(tree)
dv_sunburst(tree_cod, mode = "occurrence", colors = pal_tree,
            title = "Atlantic cod", subtitle = "share of prey records, colors by phylum")
```

Both palettes should be built from the pooled tree, not from one
stratum: only the pooled tree is sure to contain every taxon.
[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
is keyed by node id, so it works for any tree built with the same ranks.

## `dv_add_period()` and `dv_size_bins()`: covariates in one line

**Why.** Predator size is one of the strongest structuring variables in
fish diets, partly through gape limitation (Scharf et al. 2000). A diet
averaged over a predator’s whole size range mixes what small and large
individuals eat, so it is worth splitting by size. Years are grouped
into periods for the same reason: a single year rarely holds enough
stomachs.

``` r

table(cod$year)
#> 
#> 2021 2022 2023 2024 
#>   13  586 1161  544
cod$period   <- dv_add_period(cod$year, breaks = c(2021.5, 2022, 2024),
                              labels = c("2022", "2023-2024"))
cod$size_bin <- dv_size_bins(cod$length_cm, breaks = c(0, 20, 35, 50, 110))

table(cod$period, useNA = "ifany")
#> 
#>      2022 2023-2024      <NA> 
#>       586      1705        13
table(cod$size_bin, useNA = "ifany")
#> 
#>   [0, 20)  [20, 35)  [35, 50) [50, 110) 
#>       364       964       544       432
```

Cod were sampled from 2021 to 2024, but 2021 holds only 13 records. The
lower break 2021.5 leaves those records without a period (`NA`) rather
than letting them fall silently into the first level, which the default
breaks `c(2021, 2022, 2024)` would do.

**Arguments that matter.**
[`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
labels each period with the years it contains, such as `"2023-2024"`,
unless you pass `labels`; a year equal to an inner break belongs to the
earlier period.
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
uses `right = FALSE` by default, so bins include their lower edge
(`"[0, 20)"`) and a fish of exactly 20 cm falls in the second bin. A
value outside the breaks gets no level. Choose breaks on biology
(maturity, gape, the size at which a predator turns to fish) rather than
on quantiles, and state them in your methods. The article on covariates
uses these columns.

## `dv_digestion_diagnostic()`: identification depth and digestion

**Why.** Digestion affects both what can still be identified and what is
left to weigh. A table of identification depth by digestion score is
what Buckland et al. (2017) asked diet studies to report.

**What it does.** It cross-tabulates the digestion score against the
deepest rank each record was identified to, in records and in weight.

``` r

dg <- dv_digestion_diagnostic(prep)
dg$p_records <- round(dg$p_records, 1)
dg$p_weight  <- round(dg$p_weight, 1)
dg[dg$finest_rank %in% c("Species", "Class", "Phylum", "Unresolved"),
   c("digestion", "finest_rank", "n_records", "p_records", "p_weight")]
#>             digestion finest_rank n_records p_records p_weight
#> 1          0 pristine      Phylum        42       7.5      3.2
#> 2          0 pristine       Class        26       4.6      0.2
#> 6          0 pristine     Species       219      39.0     82.6
#> 7          0 pristine  Unresolved        66      11.8      1.6
#> 8          1 affected      Phylum       313       9.0      4.0
#> 9          1 affected       Class       525      15.0      3.4
#> 13         1 affected     Species      1093      31.3     72.3
#> 14         1 affected  Unresolved        23       0.7      0.1
#> 15 2 skeletal remains      Phylum       550      24.9     28.5
#> 16 2 skeletal remains       Class       720      32.6     42.6
#> 20 2 skeletal remains     Species       126       5.7     12.5
#> 21 2 skeletal remains  Unresolved       280      12.7      0.4
#> 22       not recorded      Phylum       584      25.7     27.4
#> 23       not recorded       Class        92       4.1      1.8
#> 27       not recorded     Species       128       5.6     17.9
#> 28       not recorded  Unresolved      1184      52.2     35.0
```

The labels of the ICES digestion codes (“0 pristine”, “1 affected”, “2
skeletal remains”) are inferred from the older ICES format, and 27% of
the records have no stage at all (“not recorded”). Read with that in
mind, the profile is steep: 39% of the pristine records reach species,
against 5.7% of the skeletal remains, most of which stop at class or
phylum.

**What you get back.** A data frame with `digestion`, `finest_rank`,
`n_records`, `weight`, and the percentages within each digestion score,
`p_records` and `p_weight`.

**Arguments that matter.** Percentages are computed within each
digestion score, so each score adds up to 100 whatever its sample size;
always read them next to `n_records` (here only 561 records are
pristine). Pass `by` to split the table by a covariate when you suspect
the profile differs between strata. A steep profile is a reason to be
cautious with the weight currency in particular. The vignette
“Identification depth and digestion” explains how to read the table.

## `dv_taxonomy_worms()`: the WoRMS lookup on its own

**Why.** `dv_prepare(taxonomy = "worms")` calls it for you. Call it
directly to build the lineage table you will freeze.

**What it does.** It takes a data frame of distinct prey keys and
returns their lineages and how each was matched. It tries, in order:
retrieval by AphiaID, the accepted ID behind an unaccepted name, exact
name match, then fuzzy match.

``` r

keys <- unique(dat[, c("prey_aphia_id", "prey_name")])
names(keys) <- c("prey_id", "prey_name")

tax <- dv_taxonomy_worms(keys, fuzzy = TRUE)

table(tax$match_type)
write.csv(tax, "my_lineage.csv", row.names = FALSE)   # freeze it
```

**Arguments that matter.** It expects columns named `prey_id` and
`prey_name`, one row per distinct prey, not your full record table. Each
row carries its `match_type` and `matched_name`, so you can correct a
fuzzy match by hand before you save the lineage. Successful lookups are
cached under `cache_dir`, so a rerun after correcting a spelling only
queries what changed. Failed lookups are not cached.

## `dv_species_card_assets()`: a photo and a description for a predator

**Why.** People who read a dashboard often need to recognize the
predators, not only read their diets: technicians, students new to the
fauna, managers.

``` r

dv_species_card_assets(
  predator     = "Atlantic cod",
  latin        = "Gadus morhua",
  photo_source = "inaturalist",
  image_dir    = tempdir()
)
```

**Arguments that matter.** It works for one predator at a time.
`photo_source` is `"none"` (the default), `"inaturalist"` or
`"wikipedia"`; with `"none"` the card has no photo and no description
unless you supply them in `species_info`. With iNaturalist, only photos
whose license is in `licenses` (by default CC0, CC BY, CC BY-SA) are
used, and the result carries the photographer, the license and the
photo’s page. Photos are embedded in the HTML file, so the dashboard
keeps working when `image_dir` is deleted. The article on species cards
covers image licenses.

## `dv_build_html()`, `run_dietview()`, `dv_deploy()`: sharing the result

**Why.** Many of the people who need a diet description do not use R. A
single HTML file reaches them without a running R session.

``` r

# one HTML file that opens in any browser, without R
dv_build_html(
  prep,
  output     = file.path(tempdir(), "ices_diet.html"),
  strata     = c("region", "quarter"),
  cross      = list(c("quarter", "region")),   # inner, outer
  length_col = "length_cm"
)

# interactive exploration
run_dietview(prep)
```

**Arguments that matter.** `cross = list(c(inner, outer))` reads “inner
within outer”: one row per level of `outer`, one sunburst per level of
`inner`. Crossing multiplies panels: three regions and four quarters
give up to twelve sunbursts per predator, several of them empty or
nearly so.

A dashboard is a snapshot: it holds the data as they were when you built
it. That is a limit for monitoring and an advantage for archiving.

## Application 1: records and weight disagree

Same cod tree, same records, two currencies.

``` r

cc <- dv_rank_table(tree_cod, "Class")
cc <- cc[cc$pct_occ >= 1 & cc$label != "NA", ]

data.frame(
  taxon       = cc$label,
  records_pct = round(cc$pct_occ, 1),
  weight_pct  = round(cc$pct_w, 1),
  difference  = round(cc$pct_w - cc$pct_occ, 1)
)
#>          taxon records_pct weight_pct difference
#> 1 Malacostraca        43.4       22.4      -21.0
#> 2    Teleostei        27.1       68.9       41.8
#> 3   Polychaeta         6.2        3.7       -2.5
#> 4  Ophiuroidea         2.2        0.3       -1.9
#> 5     Bivalvia         1.3        0.1       -1.2
```

Crustaceans (Malacostraca) are 43.4% of the cod’s prey records but 22.4%
of the prey weight; bony fish (Teleostei) are 27.1% of the records and
68.9% of the weight. Large prey that are eaten less often rank high by
weight; small prey eaten often do the reverse. Neither column is the
right one on its own. If you report only one, say which and why.

## Application 2: how much does the reporting rank change the picture?

The tree holds every rank, so you can compare the leading prey at
several ranks in a few lines:

``` r

for (r in c("Class", "Order", "Family", "Species")) {
  tb <- tree_cod[tree_cod$rank == r, ]
  tb <- tb[order(-tb$pct_occ), ]
  # the deepest named taxon above each node
  tb$below <- vapply(strsplit(tb$parent, "|", fixed = TRUE), function(p) {
    p <- p[p != "NA"]; if (length(p)) p[length(p)] else "(nothing)"
  }, character(1))
  tb$pct_occ <- round(tb$pct_occ, 1)
  cat("\n", r, ": top 4 by share of prey records\n")
  print(head(tb[, c("label", "below", "pct_occ")], 4), row.names = FALSE)
}
#> 
#>  Class : top 4 by share of prey records
#>         label      below pct_occ
#>  Malacostraca Arthropoda    43.4
#>     Teleostei   Chordata    27.1
#>            NA  (nothing)     8.3
#>            NA   Chordata     6.6
#> 
#>  Order : top 4 by share of prey records
#>        label        below pct_occ
#>     Decapoda Malacostraca    37.4
#>  Gobiiformes    Teleostei    10.5
#>           NA    (nothing)     8.3
#>   Gadiformes    Teleostei     7.7
#> 
#>  Family : top 4 by share of prey records
#>        label       below pct_occ
#>           NA    Decapoda    12.4
#>     Gobiidae Gobiiformes    10.5
#>  Crangonidae    Decapoda    10.4
#>           NA   (nothing)     8.3
#> 
#>  Species : top 4 by share of prey records
#>            label     below pct_occ
#>               NA  Decapoda    12.4
#>  Crangon crangon   Crangon     9.9
#>               NA (nothing)     8.3
#>               NA  Chordata     6.6
```

At class and order, the cod diet is crustaceans first, decapods above
all, and fish second. At family and species the largest single node is
an unidentified one: decapods not identified to family (`NA` below
Decapoda), because much of the material was named only “Brachyura”,
“Caridea” or “Decapoda”. The brown shrimp *Crangon crangon* is the only
named species among the top four. Two strata that look alike at class
can differ at genus. The change is then happening inside the coarse
categories, and an analysis made only at class would not see it.

## Application 3: how much of the diet was identified?

The unidentified share at a rank tells you how much of the material a
statement at that rank rests on.

``` r

na_share <- function(tr) {
  sapply(unique(tr$rank), function(r)
    round(sum(tr$pct_occ[tr$rank == r & tr$label == "NA"]), 1))
}
rbind(pooled = na_share(tree), cod = na_share(tree_cod))
#>        Kingdom Phylum Class Order Family Genus Species
#> pooled    18.2   18.2  35.7  52.0   64.2  76.3    81.6
#> cod        8.3    8.3  18.4  23.3   39.4  52.5    60.9
```

In cod, 52.5% of the records are unidentified at genus, so a genus-level
statement rests on the other 47.5%. Digestion does not remove prey at
random with respect to taxon (soft-bodied prey lose their identifying
features first), so that part is not a random sample. The vignette “A
known diet” shows what this does on a simulated survey.

## What changes what

| Argument | Where | Changes |
|----|----|----|
| `prey_id` / `prey_name` | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md) | which key is looked up; the ID is used first |
| `ranks` | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md) | the number of rings |
| `covariates` | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md) | what you can compare diets across |
| `taxonomy` | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md) | where the hierarchy comes from |
| `fuzzy` | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md) | whether misspelled names can match; the log must then be read |
| `weight_col` | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md) | whether the weight share exists |
| `count_col`, `currency` | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md), [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md) | share of prey records becomes the numerical share (%N) |
| `mode` | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md) | what sizes the wedges |
| `colors` | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md) | whether colors match across panels; pass one palette |
| `rotation` | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md) | start angle; keep it the same across panels |
| `breaks` | [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md), [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md) | the strata themselves |
| `by` | [`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md) | whether the table is split further |
| `cross` | [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md) | the panel grid, inner within outer |

## Three things to keep in mind

Every ring holds all the records. A record not identified to a rank
still appears in that rank’s ring, as unidentified, so no share is
rescaled to the identified records only, and each ring can be read on
its own.

The share of prey records is not %FO. %FO counts stomachs and does not
add up across ranks;
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
computes it. Name the quantity you report.

A DietView figure can be reproduced from three files: the data, the
specification and the lineage table. Resolve the taxonomy once, read the
report, archive the lineage table, and run everything from that
snapshot.

## References

Buckland, A., Baker, R., Loneragan, N., & Sheaves, M. (2017).
Standardising fish stomach content analysis: the importance of prey
condition. *Fisheries Research*, 196, 126–140.

ICES Stomach Content Database. ICES, Copenhagen.
<https://stomachdata.ices.dk>. Extract distributed with the R package
stomachr (Lindmark 2026, <https://github.com/maxlindmark/stomachr>).

Scharf, F. S., Juanes, F., & Rountree, R. A. (2000). Predator size–prey
size relationships of marine fish predators: interspecific variation and
effects of ontogeny and body size on trophic-niche breadth. *Marine
Ecology Progress Series*, 208, 229–248.
