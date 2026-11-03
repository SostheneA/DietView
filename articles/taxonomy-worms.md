# Resolving prey taxonomy with WoRMS

DietView can attach a taxonomic lineage to every prey by querying the
[World Register of Marine Species
(WoRMS)](https://www.marinespecies.org/). This vignette shows how to run
the lookup, how to read the log of how each prey was matched, and how to
freeze the result so that later runs need no network. The lookup chunks
are shown but not run, because they need the `worrms` package and an
internet connection. Everything else runs on the public ICES
stomach-content extract that ships with the package (ICES Stomach
Content Database, ICES, Copenhagen; extract distributed with the R
package stomachr, Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md))
and on its frozen lineage, `ices_lineage`.

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
```

## Why a lineage, and why unidentified records stay

DietView shows the diet at seven ranks, kingdom to species, by default.
Your records rarely carry all seven: identification often stops at a
coarse rank. In the ICES data, prey are recorded at every level WoRMS
knows:

``` r

ids <- unique(stats::na.omit(dat$prey_aphia_id))
sort(table(ices_lineage$worms_rank[ices_lineage$prey_aphia_id %in% ids]), decreasing = TRUE)
#> 
#>           Species            Family             Genus             Class 
#>               110                53                36                13 
#>             Order            Phylum        Infraorder          Subclass 
#>                13                 7                 4                 3 
#>        Parvphylum         Subphylum        Superclass         Gigaclass 
#>                 2                 2                 2                 1 
#>       Infraphylum Phylum (Division)         Subfamily          Suborder 
#>                 1                 1                 1                 1 
#>        Subspecies        Superorder 
#>                 1                 1
```

Only some of these 252 prey names are species. The others stop at a
genus, a family, or something as coarse as “Crustacea” (a subphylum) or
“Pisces” (a superclass). DietView never fills in the missing ranks.
Below the last rank reached, the record is shown as unidentified at that
rank, so every ring of the sunburst still holds all the records and adds
up to 100%.

## Running the lookup

`dv_prepare(taxonomy = "worms")` calls
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
once for each distinct prey key, not once per record: here 252 AphiaIDs
for 8,530 records. Each record is keyed by its AphiaID when it has one,
and by its name otherwise.

``` r

prep <- dv_prepare(dat, spec, taxonomy = "worms")
prep
```

In the ICES data, the only records without an AphiaID are the
unidentified material, named “Unidentified material”. That name would be
sent to WoRMS as a name, fail the exact match and go to fuzzy matching,
which has nothing useful to find. Remove the name from the lookup, so
these records stay plainly unidentified
([`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
then warns that they have no key, which is what you want):

``` r

lookup <- dat
lookup$prey_name[lookup$item_type == "unidentified"] <- NA
prep <- dv_prepare(lookup, spec, taxonomy = "worms")
```

## How each prey is matched

Each distinct prey gets one row in the log, with a `match_type`:

| `match_type` | Meaning | What to do |
|----|----|----|
| `id` | The AphiaID is accepted in WoRMS | Nothing, unless `name_check` is `"differs"` |
| `id_synonym` | The AphiaID is unaccepted; its accepted ID was used | Check that the accepted name is the taxon you meant |
| `id_unchecked` | WoRMS could not be reached to check the ID | Run again later |
| `id_fallback_name` | WoRMS does not know the AphiaID; the prey name was matched instead | Check the ID in your data, and that the name is the taxon you meant |
| `exact` | No ID; the name matched exactly | Nothing |
| `fuzzy` | No ID; the name was matched by TAXAMATCH, which tolerates misspellings | Check every one: a near match can be a different taxon |
| `unresolved` | No match | Correct the name, or accept that the prey stays unidentified |

### Matching by AphiaID: `id` and `id_synonym`

Every ICES prey record carries an AphiaID, so a lookup on these data
runs almost entirely through the first two rows of the table. Most IDs
are accepted (`id`). Some are not. The package ships the lineage twice:
`ices_lineage_raw` as the stomachr lookup built it, from the AphiaIDs as
reported, and `ices_lineage`, where unaccepted AphiaIDs carry the
lineage of their accepted record.
[`dv_lineage_check()`](https://sosthenea.github.io/DietView/reference/dv_lineage_check.md)
finds the spelling variants in the raw table without going online:

``` r

dv_lineage_check(ices_lineage_raw)[, c("check", "rank", "parent", "label", "variant")]
#>            check    rank       parent                    label
#> 1 near_duplicate   genus Aphroditidae                Aphrodita
#> 2 near_duplicate species  Trisopterus      Trisopterus esmarki
#> 3 near_duplicate species     Lumpenus Lumpenus lampetraeformis
#>                    variant
#> 1                Aphrodite
#> 2     Trisopterus esmarkii
#> 3 Lumpenus lampretaeformis
pairs <- c("Aphrodita aculeata", "Aphrodite aculeata",
           "Trisopterus esmarkii", "Trisopterus esmarki",
           "Lumpenus lampretaeformis", "Lumpenus lampetraeformis")
lin_pairs <- ices_lineage_raw[ices_lineage_raw$scientific_name %in% pairs,
                              c("prey_aphia_id", "scientific_name", "family", "species")]
lin_pairs$n_records <- as.vector(table(dat$prey_aphia_id)[as.character(lin_pairs$prey_aphia_id)])
lin_pairs
#>     prey_aphia_id          scientific_name       family
#> 24         126444     Trisopterus esmarkii      Gadidae
#> 139        129840       Aphrodita aculeata Aphroditidae
#> 190        154675 Lumpenus lampretaeformis   Lumpenidae
#> 310        231869       Aphrodite aculeata Aphroditidae
#> 311        400596      Trisopterus esmarki      Gadidae
#> 317        298205 Lumpenus lampetraeformis   Lumpenidae
#>                      species n_records
#> 24      Trisopterus esmarkii        35
#> 139       Aphrodita aculeata        47
#> 190 Lumpenus lampretaeformis        NA
#> 310       Aphrodite aculeata        31
#> 311      Trisopterus esmarki        73
#> 317 Lumpenus lampetraeformis         1
table(dat$prey_name[dat$prey_name %in% pairs], dat$country[dat$prey_name %in% pairs])
#>                           
#>                            DE DK NL NO SE
#>   Aphrodita aculeata        8  0 12  0 27
#>   Aphrodite aculeata        0 31  0  0  0
#>   Lumpenus lampetraeformis  0  1  0  0  0
#>   Trisopterus esmarki       0 73  0  0  0
#>   Trisopterus esmarkii      9  0 21  1  4
```

Each pair is one species (a sea mouse, Norway pout and the snake blenny)
under two AphiaIDs, and the variant spellings come from few countries.
WoRMS keeps spellings like these as unaccepted names with AphiaIDs of
their own. A live lookup reads each AphiaID’s record; when it is
unaccepted, it follows it to the accepted AphiaID, logs it as
`id_synonym` and gives both spellings the same lineage. A lineage frozen
from the AphiaIDs as reported keeps them apart, and the species ring
counts each species twice. It matters for any species-level statement:

``` r

cod <- dat[dat$predator_common == "Atlantic cod", ]
prep_raw <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage_raw,
                       verbose = FALSE)
fo_split <- dv_fo_table(prep_raw, rank = "species")
fo_split[fo_split$taxon %in% pairs, ]
#>       rank                    taxon n_stomachs n_total pct_fo
#> 5  species       Aphrodita aculeata         42     991   4.24
#> 6  species       Aphrodite aculeata         25     991   2.52
#> 9  species      Trisopterus esmarki         21     991   2.12
#> 14 species     Trisopterus esmarkii         15     991   1.51
#> 57 species Lumpenus lampetraeformis          1     991   0.10
```

`ices_lineage` was corrected once, in `data-raw/ices_data.R`, by giving
each unaccepted AphiaID the lineage of its accepted record; the keys are
unchanged, so the same records join to the accepted name and the check
is clean:

``` r

nrow(dv_lineage_check(ices_lineage))
#> [1] 0
ices_lineage[ices_lineage$prey_aphia_id %in% c(231869, 400596, 298205),
             c("prey_aphia_id", "scientific_name", "species")]
#>     prey_aphia_id          scientific_name                  species
#> 310        231869       Aphrodita aculeata       Aphrodita aculeata
#> 311        400596     Trisopterus esmarkii     Trisopterus esmarkii
#> 317        298205 Lumpenus lampretaeformis Lumpenus lampretaeformis
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)
fo <- dv_fo_table(prep_cod, rank = "species")
fo[fo$taxon %in% pairs, ]
#>       rank                    taxon n_stomachs n_total pct_fo
#> 3  species       Aphrodita aculeata         67     991   6.76
#> 6  species     Trisopterus esmarkii         36     991   3.63
#> 55 species Lumpenus lampretaeformis          1     991   0.10
```

With your own frozen table, make the same correction in the script that
builds it, one line per pair, and keep the comment, so the change is
visible.

Merged, the sea mouse is found in 67 cod stomachs (6.76%) and ranks
number 2 among the named species of the cod diet by frequency of
occurrence; split, its more common spelling ranked number 4.

`name_check` compares the name in your table with the name WoRMS holds
for the AphiaID. In `ices_diet` the prey names were taken from WoRMS by
AphiaID, so they agree by construction. In your own data, `"differs"`
usually means that a name or an ID was mistyped, and the two point to
different taxa.

### Matching by name: `exact` and `fuzzy`

Names are used only when there is no AphiaID. To see what that path
does, take a few ICES prey names, one of them misspelled:

``` r

keys <- data.frame(prey_id   = NA,
                   prey_name = c("Crangon crangon", "Ammodytidae", "Crangon crangom"))
dv_taxonomy_worms(keys)
```

The first two names should come back as `exact`. The third fails the
exact match; with `fuzzy = TRUE`, WoRMS TAXAMATCH proposes the closest
name it knows and the row is logged as `fuzzy`, with the proposal in
`matched_name`. For a one-letter slip the proposal is usually the
intended name, but a near match can just as well be another taxon one
letter away. Check every fuzzy row.

### The other columns of the log

`lineage_ok` is `FALSE` when the prey was matched but WoRMS returned no
classification, for example because the connection failed. Those prey
count as unidentified at every rank until you run the lookup again.
Failed lookups are not stored in the cache, so the next run asks WoRMS
again. `names_seen` lists every name found under one key: more than one
name under the same AphiaID is worth a look. `homonym` flags a name with
several accepted WoRMS records.

Successful lookups are cached on disk (in
`tools::R_user_dir("DietView", "cache")`), so a rerun only queries what
changed. The log also records when the taxonomy was retrieved and which
`worrms` version was used, in its `retrieved` and `worrms_version`
attributes.

## Reading the report

[`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
returns the prey that need a look, largest number of records first:

``` r

review <- dv_taxonomy_report(prep, which = "review")
review

# the whole log, to archive or to send to a co-author
dv_taxonomy_report(prep, which = "all", file = file.path(tempdir(), "taxonomy_log.csv"))
```

On the ICES data, the rows to expect there are unaccepted AphiaIDs
(`id_synonym`), with the number of records each one affects. Unresolved
prey you did not expect are the ones to chase.

## The frozen alternative: `ices_lineage`

A lineage table is the reproducible path: no network, no change between
runs. `ices_lineage` is one such table, with one row per AphiaID:

``` r

dim(ices_lineage)
#> [1] 461  10
ices_lineage[ices_lineage$scientific_name %in% c("Crangon crangon", "Ammodytidae",
                                                  "Crustacea", "Pisces"), ]
#>    prey_aphia_id scientific_name worms_rank  kingdom     phylum        class
#> 48        107552 Crangon crangon    Species Animalia Arthropoda Malacostraca
#> 77          1066       Crustacea  Subphylum Animalia Arthropoda         <NA>
#> 81         11676          Pisces Superclass Animalia   Chordata         <NA>
#> 92        125516     Ammodytidae     Family Animalia   Chordata    Teleostei
#>          order      family   genus         species
#> 48    Decapoda Crangonidae Crangon Crangon crangon
#> 77        <NA>        <NA>    <NA>            <NA>
#> 81        <NA>        <NA>    <NA>            <NA>
#> 92 Perciformes Ammodytidae    <NA>            <NA>
```

It was not produced by
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md).
It comes from the WoRMS classification that the R package stomachr
(Lindmark 2026) compiled for the AphiaIDs of the ICES extract; the
script `data-raw/ices_data.R` in the package sources reshapes it into
DietView’s seven ranks. Two columns are derived there rather than read
from WoRMS: `kingdom`, from the phylum, and `species`, from the name
when its WoRMS rank is species or subspecies (a subspecies is reported
under its species). A name above species keeps only the ranks WoRMS
gives it, so “Crustacea” has a phylum and nothing below. It is used with
`taxonomy = "table"`; the key column `prey_aphia_id` has the same name
as the prey key of `ices_diet`:

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

A table path has no match log: the lineage is taken as given.
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
warns if a prey key is missing from the table, and those records are
kept as unidentified at every rank.

## Correcting and freezing your own lookup

Fix the names or IDs the report lists in your source table and run the
lookup again. When the log is clean, save the lineage, keyed by the same
column as your data, and switch to the offline path for every later run:

``` r

lineage <- unique(prep$data[, c(spec$prey_id, prep$ranks)])
lin_file <- file.path(tempdir(), "lineage_2026-10-20.csv")   # use your project folder
write.csv(lineage, lin_file, row.names = FALSE)

lineage <- read.csv(lin_file, na.strings = c("NA", ""))
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = lineage)
```

The lineage table fixes the taxonomic snapshot your figures were made
from. Archive it with your data, together with the log, and note the
retrieval date and the `worrms` version, because WoRMS changes.

## Exact matching only

To turn off TAXAMATCH matching and keep only known AphiaIDs and exact
names:

``` r

prep <- dv_prepare(dat, spec, taxonomy = "worms", fuzzy = FALSE)
```
