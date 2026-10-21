# A guided tour of the main functions

This article goes through the package one function at a time. For each
function it says why you would use it, what it does, what it returns,
and which arguments change the answer. It ends with three short
applications that show how much a result moves when you change the
currency or the rank you report at. Everything runs offline on the
invented example table that ships with the package: 24 prey records from
11 stomachs of three predators. The numbers show the mechanics, not the
diet of these fish.

``` r

library(DietView)
```

## The pipeline

DietView is a short pipeline. Every step returns an object you can
print, inspect and save.

| Step | Function | Returns |
|----|----|----|
| Declare | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md) | `dietview_spec`: which column plays which role |
| Check | [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md) | the data, invisibly, with messages about it |
| Prepare | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md) | `dietview_prep`: data, taxonomy and matching log |
| Review | [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md) | the matches that need a look |
| Count | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md) | `dietview_tree`: one row per node, with records, weight and shares |
| Read | [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md) | the rows of one ring |
| Draw | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md) | a plotly figure |
| Share | [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md), [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md), [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md) | an HTML file, a Shiny app, a deployed file |

Two helpers
([`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md),
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md))
build covariates,
[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
sets the colors,
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
relates identification depth to digestion, and
[`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
finds a photo and a description for a predator.

``` r

dat <- read.csv(
  system.file("extdata", "dietview_example.csv", package = "DietView"),
  na.strings = c("NA", "")
)
lineage <- read.csv(
  system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
  na.strings = c("NA", "")
)

str(dat, vec.len = 2, give.attr = FALSE)
#> 'data.frame':    24 obs. of  14 variables:
#>  $ predator_species_common_name: chr  "Atlantic cod" "Atlantic cod" ...
#>  $ predator_species_latin_name : chr  "Gadus morhua" "Gadus morhua" ...
#>  $ stomach_id                  : chr  "GM001" "GM001" ...
#>  $ aphia_id                    : int  107649 126752 1130 101107 293496 ...
#>  $ verified_name               : chr  "Pandalus borealis" "Ammodytes dubius" ...
#>  $ prey_weight                 : num  12.3 5.1 2 0.8 8 ...
#>  $ number_of_prey              : int  3 2 1 20 1 ...
#>  $ digestion_level_id          : int  2 3 4 2 4 ...
#>  $ period                      : chr  "2004-2006" "2004-2006" ...
#>  $ year                        : int  2005 2005 2005 2005 2005 ...
#>  $ somatic_length_cm           : int  45 45 45 52 52 ...
#>  $ size_class                  : chr  "adult" "adult" ...
#>  $ size_bin                    : chr  "[40, 50)" "[40, 50)" ...
#>  $ region                      : chr  "Northumberland" "Northumberland" ...
```

One row is one prey record: one prey taxon found in one stomach. There
are no `kingdom` to `species` columns; DietView adds them.

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
  predator   = "predator_species_common_name",
  stomach    = "stomach_id",
  prey_id    = "aphia_id",
  prey_name  = "verified_name",
  weight     = "prey_weight",
  digestion  = "digestion_level_id",
  covariates = c("period", "size_class", "region")
)

str(spec)
#> List of 10
#>  $ predator      : chr "predator_species_common_name"
#>  $ stomach       : chr "stomach_id"
#>  $ prey_name     : chr "verified_name"
#>  $ prey_id       : chr "aphia_id"
#>  $ weight        : chr "prey_weight"
#>  $ count         : NULL
#>  $ digestion     : chr "digestion_level_id"
#>  $ covariates    : chr [1:3] "period" "size_class" "region"
#>  $ ranks         : chr [1:7] "kingdom" "phylum" "class" "order" ...
#>  $ predator_latin: NULL
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
so a common name is fine.

*The name does not have to be a species.* `Decapoda`, `Amphipoda` and
`Teleostei` are valid values: they record the rank at which
identification stopped. Do not replace them with a guessed species;
DietView shows such records as unidentified below the rank they reached.

*`ranks` defaults to seven ranks*, kingdom to species. Shorten it if
your prey are never identified past family; the sunburst then has fewer
rings.

*`covariates` lists what you can later compare diets across.* Declaring
a column costs nothing.

*`count`* declares a column of individuals per record, for the numerical
share (%N). It is left out here. If you declare it, build trees with
`dv_tree(prep, "numbers")` when you want %N, and note that records
without a count, usually the unidentified material, then contribute
nothing.

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
#> 24 records from 11 stomachs of 3 predator(s); 1 stomach(s) hold a single record; 0 record(s) lack a weight.
```

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
  taxonomy = "table",   # offline: use the lineage table supplied
  lineage  = lineage,
  verbose  = FALSE
)

class(prep)
#> [1] "dietview_prep"
names(prep)
#> [1] "data"            "spec"            "ranks"           "taxonomy_source"
#> [5] "taxonomy_log"
```

**What you get back.** A `dietview_prep` list. Its main components are:

- `data`: your table plus one column per rank;
- `spec`: the specification;
- `ranks`: the ranks used;
- `taxonomy_log`: on the WoRMS path, one row per distinct prey with how
  it was matched.

``` r

prep$ranks
#> [1] "kingdom" "phylum"  "class"   "order"   "family"  "genus"   "species"
head(prep$data[, c("verified_name", prep$ranks)], 4)
#>        verified_name  kingdom     phylum        class       order      family
#> 1  Pandalus borealis Animalia Arthropoda Malacostraca    Decapoda  Pandalidae
#> 2   Ammodytes dubius Animalia   Chordata    Teleostei Perciformes Ammodytidae
#> 3           Decapoda Animalia Arthropoda Malacostraca    Decapoda        <NA>
#> 4 Themisto libellula Animalia Arthropoda Malacostraca   Amphipoda  Hyperiidae
#>       genus            species
#> 1  Pandalus  Pandalus borealis
#> 2 Ammodytes   Ammodytes dubius
#> 3      <NA>               <NA>
#> 4  Themisto Themisto libellula
```

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
one fixed taxonomic snapshot. Different versions of an authority can
return different lineages, so an archived lineage table plays the same
role for the taxonomy as a lockfile does for package versions.

*`fuzzy = TRUE` has a cost.* It can match a misspelled name, and it can
also match a different taxon whose name is close. Every such match is
logged with `match_type = "fuzzy"`, and you need to read the log to
catch the wrong ones.

*The number of lookups depends on the number of distinct prey, not on
the number of records.* Two million records with three thousand distinct
prey need three thousand lookups.

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
matching history, because you did the matching when you built the table,
and this function stops with a message saying so. The review therefore
belongs to the one online run in the resolve-once-then-freeze workflow,
not to every rerun.

`which = "review"` (the default) returns fuzzy and unresolved matches,
unaccepted IDs that were replaced by their accepted ID, IDs that could
not be checked, names that differ from the name WoRMS holds for their
ID, and prey whose classification could not be retrieved. `"fuzzy"` and
`"unresolved"` return one of those groups; `"all"` returns the whole
log. Pass `file` to write it out.

An unresolved prey is not always an error. In this table “unidentified
material” has no AphiaID and no taxonomic name, so it should not match
anything; its records are unidentified at every rank. The unresolved
prey you did not expect are the ones to chase.

## `dv_build_tree()`: count the diet at every rank

**Why.** This is where the shares at every rank are computed.

**What it does.** It counts at the finest rank and adds up toward the
kingdom. Each node carries three values: `value_item` (the number of
distinct prey items below it), `value_occ` (the number of prey records)
and `value_w` (the summed weight). Dividing by the total gives `pct_occ`
and `pct_w`.

``` r

tree <- dv_build_tree(
  prep$data,
  ranks      = prep$ranks,
  weight_col = spec$weight
)

head(tree, 4)
#>                    id      label   parent    rank value_item value_occ value_w
#> 1            Animalia   Animalia          Kingdom         14        22 75.5968
#> 2                  NA         NA          Kingdom          1         2  1.6000
#> 3   Animalia|Annelida   Annelida Animalia  Phylum          1         2  0.7030
#> 4 Animalia|Arthropoda Arthropoda Animalia  Phylum          9        15 39.7648
#>     pct_occ      pct_w
#> 1 91.666667 97.9273752
#> 2  8.333333  2.0726248
#> 3  8.333333  0.9106595
#> 4 62.500000 51.5109435
```

**What you get back.** A `dietview_tree` data frame with `id`, `label`,
`parent`, `rank`, the three values and the two shares.

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
denominator is the same at every rank: here all 24 records.

**Arguments that matter.**

*`weight_col = NULL` is allowed* and leaves the weight view empty. The
share of prey records still works. Use it when weights are too sparse to
trust.

*`count_col` changes what one record counts for.* Left `NULL`, each
record counts once and `pct_occ` is the share of prey records. Given a
column of counts, each record counts its number of individuals and
`pct_occ` becomes the numerical share (%N). `dv_tree(prep, "numbers")`
does this from the specification. Say in your methods which one you
used.

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

dv_rank_table(tree, "Class")
#>           label value_item value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca          7        11 45.833333 39.7600 51.504725584
#> 9      Copepoda          2         4 16.666667  0.0048  0.006217874
#> 11    Teleostei          3         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta          1         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia          1         2  8.333333  0.0290  0.037566324
#> 13           NA          1         2  8.333333  1.6000  2.072624772
```

Rank labels are title case (`"Class"`, `"Family"`, `"Genus"`), built
from the specification’s `ranks`. The rows labeled `NA` are the records
unidentified at this rank, one row per parent. Keep them: dropping them
would rescale the remaining shares to the identified records only.

## `dv_sunburst()`: the whole diet in one figure

**Why.** A taxonomy is a hierarchy, and a bar chart shows one rank at a
time. A sunburst shows every rank at once.

**What it does.** It draws the tree, with records unidentified at a rank
in white wedges with gray edges.

``` r

dv_sunburst(tree, mode = "occurrence", title = "All predators",
            subtitle = "share of prey records")
```

**Arguments that matter.**

*`mode` chooses what sizes the wedges:* `"occurrence"` (prey records),
`"weight"` or `"count"` (distinct prey items). Records and weight often
rank prey differently (see Application 1), so look at both.

*`colors` matters as soon as you compare panels.* Left `NULL`, each call
builds its own palette from its own labels, so a panel with 12 taxa and
one with 9 can give the same taxon different colors. Build one palette
from the pooled tree and pass it to every panel:

``` r

colors <- dv_palette(tree$label)   # from the pooled tree: covers every taxon
head(colors, 4)
#>   Animalia   Annelida Arthropoda   Chordata 
#>  "#1f77b4"  "#aec7e8"  "#ff7f0e"  "#ffbb78"
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

## `dv_palette()`: colors, and white for unidentified records

**Why.** Across panels, a taxon is recognized by its color, and
unidentified records need to look different from everything else.

**What it does.** It gives each label a color from a 20-color palette
and makes `"NA"` white. With more than 20 taxa, colors are reused, so
check the hover labels before you read a color as a taxon.

Build it from the pooled tree, not from one stratum: only the pooled
tree is sure to contain every taxon.

## `dv_add_period()` and `dv_size_bins()`: covariates in one line

**Why.** Predator size is one of the strongest structuring variables in
fish diets, partly through gape limitation (Scharf et al. 2000). A diet
averaged over a predator’s whole size range mixes what small and large
individuals eat, so it is worth splitting by size.

``` r

dat$period2   <- dv_add_period(dat$year, breaks = c(1990, 2000, 2010, 2025))
dat$size_bin2 <- dv_size_bins(dat$somatic_length_cm, breaks = c(0, 30, 50, 200))

table(dat$period2, useNA = "ifany")
#> 
#> 1990-2000 2001-2010 2011-2025 
#>         0        12        12
table(dat$size_bin2, useNA = "ifany")
#> 
#>   [0, 30)  [30, 50) [50, 200) 
#>        12         8         4
```

**Arguments that matter.**
[`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
labels each period with the years it contains, such as `"2001-2010"`,
unless you pass `labels`; a year equal to an inner break belongs to the
earlier period.
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
uses `right = FALSE` by default, so bins include their lower edge
(`"[0, 30)"`) and a fish of exactly 30 cm falls in the second bin. A
value outside the breaks gets no level. Choose breaks on biology
(maturity, gape) rather than on quantiles, and state them in your
methods.

## `dv_digestion_diagnostic()`: identification depth and digestion

**Why.** Digestion affects both what can still be identified and what is
left to weigh. A table of identification depth by digestion score is
what Buckland et al. (2017) asked diet studies to report.

**What it does.** It cross-tabulates the digestion score against the
deepest rank each record was identified to, in records and in weight.

``` r

dg <- dv_digestion_diagnostic(prep)
head(dg, 8)
#>   digestion finest_rank n_records  weight p_records    p_weight
#> 1         1     Species         2  9.0020 100.00000 100.0000000
#> 2         2       Class         3  0.5128  33.33333   1.4334914
#> 3         2       Order         2  0.1100  22.22222   0.3074962
#> 4         2     Species         4 35.1500  44.44444  98.2590124
#> 5         3       Class         2  0.2010  28.57143   0.9662997
#> 6         3       Order         2  0.4500  28.57143   2.1633575
#> 7         3      Family         1  0.0500  14.28571   0.2403731
#> 8         3     Species         2 20.1000  28.57143  96.6299697
```

**What you get back.** A data frame with `digestion`, `finest_rank`,
`n_records`, `weight`, and the percentages within each digestion score,
`p_records` and `p_weight`.

**Arguments that matter.** Percentages are computed within each
digestion score, so each score adds up to 100 whatever its sample size;
always read them next to `n_records`. Pass `by` to split the table by a
covariate when you suspect the profile differs between strata. A steep
profile is a reason to be cautious with the weight currency in
particular. The vignette “Identification depth and digestion” explains
how to read the table.

## `dv_taxonomy_worms()`: the WoRMS lookup on its own

**Why.** `dv_prepare(taxonomy = "worms")` calls it for you. Call it
directly to build the lineage table you will freeze.

**What it does.** It takes a data frame of distinct prey keys and
returns their lineages and how each was matched. It tries, in order:
retrieval by AphiaID, the accepted ID behind an unaccepted name, exact
name match, then fuzzy match.

``` r

keys <- unique(dat[, c("aphia_id", "verified_name")])
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
  predator  = "Atlantic cod",
  latin     = "Gadus morhua",
  photo_source = "inaturalist",
  image_dir = tempdir()
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
  output = file.path(tempdir(), "dietview.html"),
  strata = c("period", "size_class"),
  cross  = list(c("size_class", "period"))   # inner, outer
)

# interactive exploration
run_dietview(prep)
```

**Arguments that matter.** `cross = list(c(inner, outer))` reads “inner
within outer”: one row per level of `outer`, one sunburst per level of
`inner`. Crossing multiplies panels: two covariates with four levels
each give sixteen sunbursts.

A dashboard is a snapshot: it holds the data as they were when you built
it. That is a limit for monitoring and an advantage for archiving.

## Application 1: records and weight disagree

Same tree, same records, two currencies.

``` r

cls <- dv_rank_table(tree, "Class")

data.frame(
  taxon       = cls$label,
  records_pct = round(cls$pct_occ, 1),
  weight_pct  = round(cls$pct_w, 1),
  difference  = round(cls$pct_w - cls$pct_occ, 1)
)
#>          taxon records_pct weight_pct difference
#> 1 Malacostraca        45.8       51.5        5.7
#> 2     Copepoda        16.7        0.0      -16.7
#> 3    Teleostei        12.5       45.5       33.0
#> 4   Polychaeta         8.3        0.9       -7.4
#> 5     Bivalvia         8.3        0.0       -8.3
#> 6           NA         8.3        2.1       -6.3
```

Large prey that are eaten rarely rank high by weight and low by records;
small prey that are eaten often do the reverse. Neither column is the
right one on its own. If you report only one, say which and why.

## Application 2: how much does the reporting rank change the picture?

The tree holds every rank, so you can compare the leading prey at
several ranks in a few lines:

``` r

for (r in c("Class", "Order", "Family")) {
  tb <- dv_rank_table(tree, r)
  cat("\n", r, ": top 3 by share of prey records\n")
  print(head(tb[, c("label", "pct_occ")], 3), row.names = FALSE)
}
#> 
#>  Class : top 3 by share of prey records
#>         label  pct_occ
#>  Malacostraca 45.83333
#>      Copepoda 16.66667
#>     Teleostei 12.50000
#> 
#>  Order : top 3 by share of prey records
#>      label   pct_occ
#>  Amphipoda 20.833333
#>   Decapoda 16.666667
#>         NA  8.333333
#> 
#>  Family : top 3 by share of prey records
#>      label  pct_occ
#>         NA 8.333333
#>  Calanidae 8.333333
#>         NA 8.333333
```

Watch for one pattern on real data: two strata that look alike at class
can differ at genus. The change is then happening inside the coarse
categories, and an analysis made only at class would not see it.

## Application 3: how much of the diet was identified?

The unidentified share at a rank tells you how much of the material a
statement at that rank rests on.

``` r

na_share <- do.call(rbind, lapply(prep$ranks, function(r) {
  lab <- paste0(toupper(substring(r, 1, 1)), substring(r, 2))
  tb  <- dv_rank_table(tree, lab)
  data.frame(rank = lab,
             unidentified_pct = round(sum(tb$pct_occ[tb$label == "NA"]), 1))
}))
na_share
#>      rank unidentified_pct
#> 1 Kingdom              8.3
#> 2  Phylum              8.3
#> 3   Class              8.3
#> 4   Order             37.5
#> 5  Family             58.3
#> 6   Genus             62.5
#> 7 Species             62.5
```

If half the records are unidentified at genus, a genus-level statement
rests on the other half. Digestion does not remove prey at random with
respect to taxon, so that half is not a random sample. The vignette “A
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
| `count_col` | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md) | share of prey records becomes the numerical share (%N) |
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

Scharf, F. S., Juanes, F., & Rountree, R. A. (2000). Predator size–prey
size relationships of marine fish predators: interspecific variation and
effects of ontogeny and body size on trophic-niche breadth. *Marine
Ecology Progress Series*, 208, 229–248.
