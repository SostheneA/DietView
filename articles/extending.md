# Adapting DietView to your own survey

DietView makes few assumptions about your data: one row per prey record,
a predator column, a stomach column and a prey key. Everything else is
declared. This article goes through the choices you make when you move
from the example table to your own survey, in the order you meet them.

``` r

library(DietView)
```

## 1. Map your columns

Tell
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)
which of your columns plays which role. Your table keeps its own column
names:

``` r

spec <- dv_spec(predator = "sp", stomach = "stom", prey_id = "aphia",
                prey_name = "prey", weight = "wt_g", digestion = "dig",
                covariates = c("yr", "zone"))
dv_validate(mydata, spec)
```

Two columns need care. The stomach identifier must be unique across the
whole table, not only within a predator or a year: stomach counts
(frequency of occurrence, aggregation thresholds, matrices) count
distinct identifiers, so two stomachs that share an identifier count as
one. If your identifiers restart each year, build a unique one first,
for example
`mydata$stom <- paste(mydata$year, mydata$sp, mydata$stom_no, sep = "_")`.
And give both a prey ID and a prey name when you have them: the ID is
used for the lookup, and the name lets DietView check that the two
agree.

## 2. Attach a taxonomy you can check

With `taxonomy = "worms"`, DietView looks each distinct prey up in the
World Register of Marine Species and keeps a log of how it was matched.
Read that log before you use the result:

``` r

prep <- dv_prepare(mydata, spec, taxonomy = "worms")
dv_taxonomy_report(prep)   # the matches that need a look, largest first
```

Each prey gets a `match_type`:

| `match_type` | Meaning | What to do |
|----|----|----|
| `id` | The AphiaID is accepted in WoRMS | Nothing, unless `name_check` is `"differs"` |
| `id_synonym` | The AphiaID is unaccepted; its accepted ID was used | Check that the accepted name is the taxon you meant |
| `id_unchecked` | WoRMS could not be reached to check the ID | Run again later |
| `exact` | No ID; the name matched exactly | Nothing |
| `fuzzy` | No ID; the name was matched by TAXAMATCH, which tolerates misspellings | Check every one: a near match can be a different taxon |
| `unresolved` | No match | Correct the name, or accept that the prey stays unidentified |

A `name_check` of `"differs"` means the name in your table is not the
name WoRMS holds for that AphiaID: either the ID or the name was
mistyped. A `lineage_ok` of `FALSE` means the prey was matched but its
classification could not be retrieved; its records count as unidentified
until you run the lookup again. Fix what the report lists, then save the
lineage.

## 3. Freeze the taxonomy for the analysis

WoRMS changes. For an analysis you will publish, resolve the taxonomy
once, save it as a lineage table, and run every later step from that
file:

``` r

lineage <- unique(prep$data[, c(spec$prey_name, prep$ranks)])
write.csv(lineage, "lineage_2026-10-20.csv", row.names = FALSE)

lineage <- read.csv("lineage_2026-10-20.csv", na.strings = c("NA", ""))
prep <- dv_prepare(mydata, spec, taxonomy = "table", lineage = lineage)
```

This path needs neither `worrms` nor a network connection, and it gives
the same result every time it is run on the same files. Archive the
lineage table with your data and record the date it was retrieved. The
lineage table needs one row per prey key, with one column per rank; an
empty cell means the prey was not identified to that rank. A prey that
is missing from the lineage table, or a key that appears twice, triggers
a warning or an error instead of passing unnoticed.

If you build the lineage table by hand, for example for prey outside
WoRMS, take the classification from one stated authority and cite it.

## 4. Choose the ranks

By default DietView shows seven ranks, kingdom to species. Pass `ranks`
to show others:

``` r

spec <- dv_spec(predator = "sp", stomach = "stom", prey_name = "prey",
                ranks = c("phylum", "class", "order", "family", "genus"))
```

Rank names are WoRMS rank names in lower case, so intermediate ranks
such as `"subclass"` or `"infraclass"` can be added on the WoRMS path.
With a lineage table, every rank you list must be a column of that
table.

Fewer ranks make a simpler figure, but they also merge information:
without `"species"`, a prey named to species and one named only to its
genus look the same. Check one more thing on your own prey list: some
taxa have no entry at one of the requested ranks in WoRMS. Such a prey
shows an unidentified node at that rank with named taxa beyond it, and
that node then mixes prey that were not identified with prey that were
identified but have no taxon at that rank. Inspect the rows of
[`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
labeled `NA` that have children before you report an unidentified share
at that rank.

## 5. Colors

[`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
gives each name a color and unidentified nodes white. Build it from the
names in your own data rather than typing them:

``` r

lin <- read.csv(system.file("extdata", "dietview_example_lineage.csv", package = "DietView"),
                na.strings = c("NA", ""))
pal <- dv_palette(lin$class)
pal
#> Malacostraca    Teleostei     Bivalvia   Polychaeta     Copepoda           NA 
#>    "#1f77b4"    "#aec7e8"    "#ff7f0e"    "#ffbb78"    "#2ca02c"    "#FFFFFF"
```

Pass the result to `dv_sunburst(colors = pal)`. To give one taxon a
color of your choice, change that element:
`pal[["Malacostraca"]] <- "#1f77b4"`. The palette has 20 colors and
reuses them after that.

## 6. Periods and length classes

Add a covariate column, list it in `dv_spec(covariates = )`, and build
periods and length bins with the helpers:

``` r

dv_add_period(c(2005, 2010, 2012, 2019), breaks = c(2003, 2010, 2020))
#> [1] 2003-2010 2003-2010 2011-2020 2011-2020
#> Levels: 2003-2010 2011-2020
dv_size_bins(c(22, 30, 41, 58), breaks = c(0, 30, 45, 60))
#> [1] [0, 30)  [30, 45) [30, 45) [45, 60)
#> Levels: [0, 30) [30, 45) [45, 60)
```

A year on an inner break goes to the earlier period (2010 above), and a
length on an inner break goes to the bin that starts there (30 cm
above). Values outside the breaks get no level. The article on
covariates shows how to compare diets across the levels.

## 7. Freshwater, terrestrial and mixed prey

WoRMS covers marine taxa and many brackish and freshwater ones. When
DietView matches a name without an ID, it restricts the search to marine
records, so a strictly freshwater or terrestrial prey named without an
AphiaID will often be `unresolved`. For such prey, build a lineage table
from an authority that covers them (for example GBIF or the Catalogue of
Life) and use `taxonomy = "table"` (section 3). If your prey list mixes
marine and other taxa, resolve the marine part with WoRMS, append the
rest by hand from the other authority, and say in your methods which
authority supplied which part.
