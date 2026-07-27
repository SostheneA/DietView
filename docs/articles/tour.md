# A guided tour: every flagship function, what it does, and why

This article walks the whole package, function by function. For each one
it gives the same four things:

- **Why** the function exists – the problem it solves;
- **What it does** – the mechanics;
- **What you get back** – the actual object;
- **Nuances** – the parameter choices that change the answer, and the
  traps.

It closes with side-by-side applications that show how much the answer
moves when you change a currency or a reporting rank. Everything runs
offline on the bundled example data.

``` r
library(DietView)
```

## The mental model

DietView is a short linear pipeline carrying three objects. Nothing is
hidden: every stage returns something you can print, inspect and export.

| Stage     | Function                                                                                                                                                                                                                                               | Object produced                                     |
|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------|
| Declare   | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)                                                                                                                                                                               | `dietview_spec` – the column mapping                |
| Check     | [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)                                                                                                                                                                       | nothing; reports on the data                        |
| Prepare   | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)                                                                                                                                                                         | `dietview_prep` – data + taxonomy + provenance log  |
| Review    | [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)                                                                                                                                                         | data.frame of matches needing a human eye           |
| Aggregate | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)                                                                                                                                                                   | `dietview_tree` – nodes with within-rank importance |
| Read      | [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)                                                                                                                                                                   | data.frame – the numbers behind one ring            |
| Show      | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)                                                                                                                                                                       | plotly figure                                       |
| Ship      | [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md), [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md), [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md) | dashboard, app, deployment                          |

Two helpers
([`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md),
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md))
build covariates, one
([`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md))
controls colour, one
([`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md))
quantifies identification bias, and one
([`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md))
fetches identification material.

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
#>  $ size_bin                    : chr  "[40-50[" "[40-50[" ...
#>  $ region                      : chr  "Northumberland" "Northumberland" ...
```

One row is **one prey record in one stomach**. There are no
`kingdom .. species` columns – DietView adds them.

## `dv_spec()` – declare your columns once

**Why.** Every survey names its columns differently. The alternative to
a specification object is renaming columns to canonical names before
analysis, which is a destructive, undocumented step performed outside
the analysis: the published code then operates on a table that no longer
matches the archived data. A spec keeps the original table untouched and
makes the mapping an artefact you can print, archive and compare between
studies.

**What it does.** Stores which column plays which role. Nothing else. No
data is touched.

``` r
spec <- dv_spec(
  predator   = "predator_species_common_name",
  stomach    = "stomach_id",
  prey_id    = "aphia_id",
  prey_name  = "verified_name",
  weight     = "prey_weight",
  count      = "number_of_prey",
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
#>  $ count         : chr "number_of_prey"
#>  $ digestion     : chr "digestion_level_id"
#>  $ covariates    : chr [1:3] "period" "size_class" "region"
#>  $ ranks         : chr [1:7] "kingdom" "phylum" "class" "order" ...
#>  $ predator_latin: NULL
#>  - attr(*, "class")= chr "dietview_spec"
```

**Nuances.**

*`prey_id` takes precedence over `prey_name`.* Supply both when you have
both: the identifier resolves unambiguously, and the name is kept for
the provenance log so you can read what you are reviewing. Where the
identifier is missing, the name is the fallback.

*`prey_name` must be the scientific (Latin) name*, because it is sent to
WoRMS, which does not know common names. A common name either fails to
resolve or – worse – fuzzy-matches to a plausible wrong lineage. Note
the asymmetry with `predator`, which is a **common** name here: the
predator is never resolved against any authority, it is only a grouping
and display label.

*The name does not have to be a species.* `Decapoda`, `Amphipoda` and
`Teleostei` are all valid values – they are simply the rank at which
identification stopped. Do not invent a species to “complete” a record;
that is exactly what the explicit NA machinery is for.

*`ranks` defaults to the seven Linnaean ranks* (`kingdom` to `species`).
Shorten it if your prey are never resolved past family; the sunburst
then has fewer rings and reads more clearly.

*`covariates` is what you can later stratify and cross by.* Declaring a
column here costs nothing and enables it downstream, so declare
generously.

## `dv_validate()` – see the shape of your data before you trust it

**Why.** Most diet datasets have problems that stay invisible until they
have already distorted a figure. Validation surfaces them at the point
where you can still act.

**What it does.** Confirms declared columns exist, that a prey key is
present, that covariates exist, and reports on what is missing. It
**reports rather than repairs**: a dataset with a third of weights
missing is analysable in the occurrence currency and misleading in the
weight currency, and that judgement is yours to make.

``` r
dv_validate(dat, spec)
```

**What you get back.** The data, invisibly – so the value is in the
messages and warnings, not the return value. Errors are hard stops (a
declared column absent); warnings and messages are informational (no
weight column, no digestion column).

**Nuance.** Silence is a pass. If you see nothing, every declared column
was found and the currencies you asked for are available.

## `dv_prepare()` – attach taxonomy, and log how

**Why.** This is where grouping stops being an analyst’s judgement call
and becomes a lookup against an external, versioned authority. It is the
single change that makes two surveys comparable without recoding.

**What it does.** Validates, resolves the **distinct** prey keys against
a taxonomic source, joins the lineage back to every record, and fills
the ranks below the identification point with an explicit `"NA"` marker.

``` r
prep <- dv_prepare(
  dat, spec,
  taxonomy = "table",   # offline: use the supplied lineage
  lineage  = lineage,
  verbose  = FALSE
)

class(prep)
#> [1] "dietview_prep"
names(prep)
#> [1] "data"  "spec"  "ranks"
```

**What you get back.** A `dietview_prep` list with four components:

- `data` – your original table plus the rank columns;
- `spec` – the spec, carried along;
- `ranks` – the ranks actually populated;
- `taxonomy_log` – one row per distinct prey, with how it resolved.

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

**Nuances.**

*`taxonomy =` chooses the source and matters more than any other
argument here.*

| Value       | Behaviour                               | When to use                                        |
|-------------|-----------------------------------------|----------------------------------------------------|
| `"auto"`    | use rank columns if present, else WoRMS | quick exploration                                  |
| `"columns"` | trust rank columns already in the data  | taxonomy resolved elsewhere                        |
| `"worms"`   | query WoRMS online                      | first pass on a new dataset                        |
| `"table"`   | join a supplied lineage table           | reproducible reruns, offline work, non-marine prey |

*The recommended production pattern is resolve once, then freeze.* Run
with `taxonomy = "worms"` a single time, review the log, export the
resulting lineage, and thereafter run with `taxonomy = "table"`. This
makes later runs offline and fast, and it pins the taxonomic snapshot –
different versions of an authority can return different lineages, so an
archived lineage is to taxonomy what a lockfile is to package versions.

*`fuzzy = TRUE` is a convenience with a cost.* It rescues misspellings,
and it can silently attach a plausible wrong lineage. It is safe only
because every fuzzy hit is logged – which is worth nothing if you do not
read the log. See the next function.

*Resolution scales with taxonomic diversity, not with sample size.* Two
million records containing three thousand distinct prey cost three
thousand lookups.

## `dv_taxonomy_report()` – read the log before you plot

**Why.** Fuzzy matches and unresolved names are the two places where a
diet description silently goes wrong. This is the review step.

**What it does.** Returns the rows of the provenance log that need a
human eye.

``` r
prep_online <- dv_prepare(dat, spec, taxonomy = "worms")

dv_taxonomy_report(prep_online, which = "review")   # fuzzy + unresolved
dv_taxonomy_report(prep_online, which = "all",      # archive the whole log
                   file = "taxonomy_log.csv")
```

**Nuance you will meet immediately.** The provenance log only exists on
the WoRMS path. A `prep` built with `taxonomy = "table"` – as everywhere
else in this article, so that it runs offline – has
`taxonomy_log = NULL`, and this function stops with a message saying so.
That is deliberate: a lineage table you supplied yourself has no
matching history to report, because you did the matching. It also means
the review step belongs to the **one** online run in the
resolve-once-then-freeze pattern, not to every rerun.

`which = "review"` (the default) is fuzzy plus unresolved – the
actionable set. `"fuzzy"` and `"unresolved"` isolate one or the other;
`"all"` returns the full log, which is what you archive alongside the
analysis. Pass `file =` to write it out.

Unresolved is not necessarily an error. In this dataset
`"unidentified material"` has no AphiaID and no taxonomic meaning, so it
*should* fail to resolve – it becomes the explicit NA category.
Unresolved entries you did not expect are the ones to chase.

## `dv_build_tree()` – the metrics core

**Why.** This is where within-rank importance is computed, and it is the
analytical heart of the package.

**What it does.** Aggregates at the finest rank, then rolls up. Three
quantities travel with every node: `value_item` (distinct terminal
items), `value_occ` (occurrence count), `value_w` (summed weight). It
then divides each by its **rank total** to give `pct_occ` and `pct_w`.

``` r
tree <- dv_build_tree(
  prep$data,
  ranks      = prep$ranks,
  weight_col = spec$weight
)

head(tree, 4)
#>                    id      label   parent    rank value_occ value_w   pct_occ
#> 1            Animalia   Animalia          Kingdom        22 75.5968 91.666667
#> 2                  NA         NA          Kingdom         2  1.6000  8.333333
#> 3   Animalia|Annelida   Annelida Animalia  Phylum         2  0.7030  8.333333
#> 4 Animalia|Arthropoda Arthropoda Animalia  Phylum        15 39.7648 62.500000
#>        pct_w
#> 1 97.9273752
#> 2  2.0726248
#> 3  0.9106595
#> 4 51.5109435
```

**What you get back.** A `dietview_tree` data.frame: `id`, `label`,
`parent`, `rank`, the three values, and the two within-rank percentages.

Two properties hold **by construction**, and both are worth verifying
once so you trust them thereafter:

``` r
# 1. every rank is a complete partition (each sums to 100%)
round(tapply(tree$pct_occ, tree$rank, sum), 6)
#>   Class  Family   Genus Kingdom   Order  Phylum Species 
#>     100     100     100     100     100     100     100

# 2. a parent's value equals the sum of its children (largest gap should be 0)
kid_sums <- tapply(tree$value_occ, tree$parent, sum)
parents  <- intersect(tree$id, names(kid_sums))
max(abs(tree$value_occ[match(parents, tree$id)] - kid_sums[parents]))
#> [1] 0
```

The first is what lets you read any ring on its own. The second is what
a nested sunburst requires – `branchvalues = "total"` draws a parent as
the sum of its children, and a tree that violates this renders
inconsistently.

**Nuances.**

*`weight_col = NULL` is legal* and gives an empty weight view.
Occurrence still works. This is the right setting when weights are too
sparse to trust.

*`count_col` changes what one “occurrence” means.* Left `NULL`, each
record contributes 1. Supplied, each record contributes its count –
which turns the occurrence currency into a numerical (%N-like) currency.
Choose deliberately and say which you used.

*`value_occ` is a count of prey records, not a count of stomachs.* This
is the one thing about the package most likely to be misread. It is a
share of records, close in spirit to %N; it is **not** the frequency of
occurrence (%F) of the classical literature, which counts stomachs and
whose values at a parent rank are *not* the sum of its children (a
stomach containing two congeners counts once for the genus but twice
among the species). A genuine %F cannot be drawn as a nested sunburst
for exactly that reason: the geometry demands additivity and %F is not
additive. Report the currency by its real name.

## `dv_rank_table()` – the numbers behind one ring

**Why.** A figure is for seeing; a table is for reporting. Journals want
numbers, and so does anyone checking your work.

**What it does.** Extracts one rank from the tree, sorted by occurrence
share, with the explicit NA row included.

``` r
dv_rank_table(tree, "Class")
#>           label value_occ   pct_occ value_w        pct_w
#> 10 Malacostraca        11 45.833333 39.7600 51.504725584
#> 9      Copepoda         4 16.666667  0.0048  0.006217874
#> 11    Teleostei         3 12.500000 35.1000 45.468205936
#> 8    Polychaeta         2  8.333333  0.7030  0.910659509
#> 12     Bivalvia         2  8.333333  0.0290  0.037566324
#> 13           NA         2  8.333333  1.6000  2.072624772
```

**Nuances.** Rank labels are title-case (`"Class"`, `"Family"`,
`"Genus"`) – they come from the spec’s `ranks`, capitalised. The NA row
is deliberately kept: dropping it is exactly the silent re-basing this
package exists to prevent.

## `dv_sunburst()` – the whole diet in one figure

**Why.** Taxonomy is hierarchical; bar charts are flat. One sunburst
replaces a wall of per-rank, per-currency panels.

**What it does.** Renders the multi-rank tree, unidentified prey in
white.

``` r
dv_sunburst(tree, mode = "occurrence", title = "Pooled diet, occurrence")
```

**Nuances – the three arguments that matter.**

*`mode` selects the currency.* `"occurrence"`, `"weight"`, `"count"`.
See the application below: the first two routinely disagree, and showing
both is part of an honest description.

*`colors` is the one you must not forget when comparing panels.* Left
`NULL`, each call derives its own palette from **its own** labels – so a
panel with 12 taxa and a panel with 9 give the same taxon different
colours, and the comparison you were trying to make is destroyed. Build
one global palette and pass it everywhere:

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
already do this internally; it is manual per-panel plotting that needs
the discipline.

*`rotation = 90` fixes the start angle at the top*, and internally
`sort = FALSE` stops plotly reordering wedges by size. Together with the
alphabetical node order produced by
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
this keeps reading order and start angle constant across panels.

One honest limit: this fixes reading order and start angle, **not**
absolute angular position. A panel missing a taxon shifts the wedges
that follow it, since its tree contains only the taxa present in that
stratum. Colour, not angle, is the reliable cross-panel anchor.

## `dv_palette()` – colour, and the white NA

**Why.** Comparability across panels is carried by colour, and the
unidentified category needs to be unmistakable.

**What it does.** Maps labels to a categorical palette and forces `"NA"`
to white.

**Nuance.** Always derive it from the **pooled** tree, never from a
stratum – the pooled tree is the only one guaranteed to contain every
taxon.

## `dv_add_period()` and `dv_size_bins()` – covariates in one line

**Why.** Size structures diet more strongly than almost anything else,
because gape limitation determines what is available at all. A diet
description averaged over a predator’s whole size range is averaging
over an ontogenetic trajectory. Making stratification cheap is what
makes it routine.

``` r
dat$period2   <- dv_add_period(dat$year, breaks = c(1990, 2000, 2010, 2025))
dat$size_bin2 <- dv_size_bins(dat$somatic_length_cm, breaks = c(0, 30, 50, 200))

table(dat$period2, useNA = "ifany")
#> 
#> 1990-2000 2000-2010 2010-2025 
#>         0        12        12
table(dat$size_bin2, useNA = "ifany")
#> 
#>   [0-30[  [30-50[ [50-200[ 
#>       12        8        4
```

**Nuances.**
[`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
labels intervals `"1990-2000"` and so on unless you pass `labels`.
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
uses `right = FALSE` by default, so bins are left-closed (`[0-30[`) – a
fish of exactly 30 cm falls in the *second* bin. Choose breaks on
biology (maturity, gape) rather than on quantiles, and state them in the
methods.

## `dv_digestion_diagnostic()` – make the bias visible

**Why.** Digestion determines both what can be identified and what
remains to be weighed. Reporting that relationship is what turns a
nuisance variable into a diagnostic – and it is what the standardisation
literature has asked studies to provide.

**What it does.** Cross-tabulates digestion level against the finest
rank resolved, in records and in weight.

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

**What you get back.** A data.frame with `digestion`, `finest_rank`,
`n_records`, `weight`, and the within-digestion-level percentages
`p_records` and `p_weight`.

**Nuances.** Percentages are computed **within** each digestion level,
so each level sums to 100 and levels with few records are not visually
swamped. Pass `by =` to add a third dimension (predator, region) when
you suspect the degradation profile differs between strata. A steep
profile is a warning that the weight currency in particular deserves
caution.

## `dv_taxonomy_worms()` – the resolver, on its own

**Why.** `dv_prepare(taxonomy = "worms")` calls this internally. Calling
it directly is what you do to build the lineage table you will freeze.

**What it does.** Takes a data.frame of unique prey keys and returns
their lineages plus the match log. It tries, in order: retrieval by
AphiaID, the accepted ID behind an unaccepted name, exact name match,
then fuzzy match.

``` r
keys <- unique(dat[, c("aphia_id", "verified_name")])
names(keys) <- c("prey_id", "prey_name")

tax <- dv_taxonomy_worms(keys, fuzzy = TRUE)

table(tax$match_type)              # id / exact / fuzzy / unresolved
write.csv(tax, "my_lineage.csv", row.names = FALSE)   # freeze it
```

**Nuances.** It expects columns named `prey_id` and `prey_name`, one row
per unique prey – not your full record table. Nothing is guessed
silently: every row carries its `match_type` and `matched_name` so a
fuzzy hit can be corrected by hand before you save the lineage. Results
are cached under `cache_dir`, so a rerun after a corrected spelling only
queries what changed.

## `dv_species_card_assets()` – identification material

**Why.** The audience for a dashboard often needs to *recognise* the
taxa, not just read their proportions: technicians calibrating
identification, students on an unfamiliar fauna, managers new to the
system.

``` r
dv_species_card_assets(
  c("Pandalus borealis", "Osmerus mordax"),
  use_wiki  = TRUE,
  image_dir = tempdir()
)
```

**Nuances.** `use_wiki = FALSE` builds cards offline – taxonomic
information only, no imagery. Images are fetched from an open source and
written to `image_dir`, so point it somewhere durable if you want the
dashboard to keep working after a reboot.

## `dv_build_html()`, `run_dietview()`, `dv_deploy()` – three audiences

**Why.** The audience for a diet description frequently does not run R.
A result that needs a live session is a result that will be transcribed
into a static figure and lose its structure.

``` r
# self-contained dashboard: one file, opens in any browser, no R
dv_build_html(
  prep,
  output = file.path(tempdir(), "dietview.html"),
  strata = c("period", "size_class"),
  cross  = list(c("size_class", "period"))   # inner, outer
)

# live exploration
run_dietview(prep)
```

**Nuances.** `cross = list(c(inner, outer))` reads as “inner **by**
outer”: one row per level of `outer`, one column per level of `inner`.
Crossing multiplies panels, so cost and readability both degrade with
the product of the level counts – two covariates with four levels each
is sixteen sunbursts.

A dashboard is a **snapshot**, not a live view: it embeds its data at
build time. That is a limitation for monitoring and a virtue for
archiving.

## Application 1 – the two currencies disagree

This is the comparison the package exists to make easy. Same tree, same
records, different contribution per record.

``` r
cls <- dv_rank_table(tree, "Class")

data.frame(
  taxon        = cls$label,
  occurrence   = round(cls$pct_occ, 1),
  weight       = round(cls$pct_w, 1),
  difference   = round(cls$pct_w - cls$pct_occ, 1)
)
#>          taxon occurrence weight difference
#> 1 Malacostraca       45.8   51.5        5.7
#> 2     Copepoda       16.7    0.0      -16.7
#> 3    Teleostei       12.5   45.5       33.0
#> 4   Polychaeta        8.3    0.9       -7.4
#> 5     Bivalvia        8.3    0.0       -8.3
#> 6           NA        8.3    2.1       -6.3
```

Large, rarely eaten prey rank high by weight and low by occurrence;
small, frequently eaten prey do the reverse. Neither column is the right
answer. Reporting one without the other is a choice that should be
stated, not a default.

## Application 2 – how much does the reporting rank change the story?

Because the tree carries every rank at once, a sensitivity analysis that
is normally awkward becomes three lines. This is the exercise
conventional workflows cannot perform at all, since the finer ranks were
discarded before analysis.

``` r
for (r in c("Class", "Order", "Family")) {
  tb <- dv_rank_table(tree, r)
  cat("\n--", r, "-- top 3 by occurrence share:\n")
  print(head(tb[, c("label", "pct_occ")], 3), row.names = FALSE)
}
#> 
#> -- Class -- top 3 by occurrence share:
#>         label  pct_occ
#>  Malacostraca 45.83333
#>      Copepoda 16.66667
#>     Teleostei 12.50000
#> 
#> -- Order -- top 3 by occurrence share:
#>      label   pct_occ
#>  Amphipoda 20.833333
#>   Decapoda 16.666667
#>         NA  8.333333
#> 
#> -- Family -- top 3 by occurrence share:
#>      label  pct_occ
#>         NA 8.333333
#>  Calanidae 8.333333
#>         NA 8.333333
```

Watch for the classic pattern: **stability at coarse ranks concealing
turnover at fine ranks**. If two strata look alike at class and separate
at genus, the substitution is happening *within* your coarse categories
– which is precisely what a functional-group analysis would have
reported as “no change”.

## Application 3 – how much of the diet was actually identified?

The explicit NA category is not decoration; it is the confidence bound
on every fine-rank statement in the figure.

``` r
na_share <- do.call(rbind, lapply(prep$ranks, function(r) {
  lab <- paste0(toupper(substring(r, 1, 1)), substring(r, 2))
  tb  <- dv_rank_table(tree, lab)
  data.frame(rank = lab,
             na_occurrence = round(sum(tb$pct_occ[tb$label == "NA"]), 1))
}))
na_share
#>      rank na_occurrence
#> 1 Kingdom           8.3
#> 2  Phylum           8.3
#> 3   Class           8.3
#> 4   Order          37.5
#> 5  Family          58.3
#> 6   Genus          62.5
#> 7 Species          62.5
```

Read this as a ceiling on trust. If half the records are unidentified at
genus, a genus-level claim rests on the identifiable half – and
digestibility is not random with respect to taxon, so that half is not a
random sample.

## What changes what – a summary

| Argument                | Where                                                                                                                                                                    | Changes                                           |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| `prey_id` / `prey_name` | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)                                                                                                 | which key resolves; ID wins when both given       |
| `ranks`                 | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)                                                                                                 | number of rings in the sunburst                   |
| `covariates`            | [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)                                                                                                 | what you can stratify and cross by later          |
| `taxonomy`              | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)                                                                                           | the source of grouping, and reproducibility       |
| `fuzzy`                 | [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)                                                                                           | recovers misspellings; needs the log reviewed     |
| `weight_col`            | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)                                                                                     | whether the weight currency exists                |
| `count_col`             | [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)                                                                                     | occurrence becomes a numerical currency           |
| `mode`                  | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)                                                                                         | which currency is shown                           |
| `colors`                | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)                                                                                         | cross-panel comparability – pass a global palette |
| `rotation`              | [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)                                                                                         | start angle; keep constant across panels          |
| `breaks`                | [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md), [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md) | the strata themselves                             |
| `by`                    | [`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)                                                                 | whether the bias is broken down further           |
| `cross`                 | [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)                                                                                     | the panel grid, as inner-by-outer                 |

## Three things to carry away

**The denominator is stated, per rank.** Every ring sums to 100%
including the explicit NA, so nothing is silently re-based onto the
identified fraction. That is what makes the rings independently
readable.

**The occurrence currency is a share of records.** It is not the
classical %F, which counts stomachs and is non-additive. Name it
correctly in your methods.

**Reproducibility is a workflow, not a function.** Resolve the taxonomy
once, read the provenance report, archive the lineage table, and run
everything afterwards from that snapshot with the spec. What makes a
DietView figure reproducible is those three artefacts – the data, the
spec and the lineage – not the plotting call.
