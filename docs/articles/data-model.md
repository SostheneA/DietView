# The DietView data model and input contract

This vignette shows how to describe your own table to DietView. DietView
needs one thing from your data: one row per prey record, that is, one
prey taxon found in one stomach. Taxonomy, tables, figures and
dashboards are all built from that table and from a specification that
says which column is which.

The example is the public ICES stomach-content extract that ships with
the package (ICES Stomach Content Database, ICES, Copenhagen; extract
distributed with the R package stomachr, Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)).

``` r

library(DietView)
```

## One row per prey record

Column names are free. You do not rename your data; you declare once
which column plays which role. `ices_diet` is already in the long format
DietView expects:

``` r

dim(ices_diet)
#> [1] 9639   28
names(ices_diet)
#>  [1] "stomach_id"        "prey_aphia_id"     "prey_name"        
#>  [4] "item_type"         "digestion_stage"   "digestion_label"  
#>  [7] "prey_count"        "prey_weight_g"     "prey_length_cm"   
#> [10] "haul_id"           "country"           "survey"           
#> [13] "year"              "month"             "quarter"          
#> [16] "lat"               "lon"               "ices_rectangle"   
#> [19] "depth_m"           "region"            "predator_aphia_id"
#> [22] "predator_latin"    "predator_common"   "n_fish_pooled"    
#> [25] "length_cm"         "weight_g"          "stomach_empty"    
#> [28] "regurgitated"
```

Prey columns come first (`prey_aphia_id` to `prey_length_cm`), then the
haul and the predator, repeated on every record of the same stomach. The
table has no `kingdom` to `species` columns. DietView adds them when you
attach a taxonomy, here the frozen lineage `ices_lineage` (see the
vignette on WoRMS).

## Declaring roles with `dv_spec()`

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
```

The roles, what they do, and the ICES column that fills each one:

| Role | Required | Purpose | ICES column |
|----|----|----|----|
| `predator` | yes | the predator of each record; a grouping and display label | `predator_common` |
| `stomach` | yes | the stomach each record came from; must be unique across the whole table, because stomach counts count distinct identifiers | `stomach_id` |
| `prey_id` / `prey_name` | at least one | prey keys used to attach the taxonomy | `prey_aphia_id`, `prey_name` |
| `weight` | no | the weight share (%W) | `prey_weight_g` |
| `count` | no | number of individuals per record, for the numerical share (%N). Records without a count contribute nothing to %N, so unidentified material usually disappears from that view | `prey_count` |
| `digestion` | no | enables the digestion diagnostic | `digestion_label` |
| `covariates` | no | columns you want to compare diets across | `region`, `year`, `quarter` |
| `predator_latin` | no | used to look up identification photos | `predator_latin` |

Columns you do not declare are kept and travel with the data:
`length_cm`, `country` or `ices_rectangle` can be added as covariates
later, or used to build new ones, such as length classes (see the
dashboard vignette). For the digestion role we use the readable
`digestion_label` rather than the code `digestion_stage`, because it
also says where the stage was not recorded. Its labels are inferred from
the older ICES format; check them against the ICES vocabulary before you
rely on them.

## What counts as a prey record

``` r

table(ices_diet$item_type)
#> 
#>     non_food         prey unidentified 
#>           67         8019         1553
```

`item_type` sorts the records into three kinds. `prey` records carry a
WoRMS AphiaID. `unidentified` records are food that could not be named;
they have no AphiaID, and DietView keeps them as unidentified at every
rank, which is the point of the package. `non_food` records are sand,
stones, plastic and wood: real observations, but not diet, so they are
dropped before the analysis.

Nematodes are a different case. They do have an AphiaID, but in fish
stomachs they are mostly parasites of the fish rather than food. The
lineage tells you which records they are:

``` r

# drop non-food items and nematodes (mostly parasites, not prey)
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
c(nematoda = sum(phylum %in% "Nematoda"), kept = nrow(dat))
#> nematoda     kept 
#>     1042     8530
```

Both choices belong to the analyst, which is why the data keep these
records and the filter is written out in the code. Dropping them also
removes 9 stomachs whose only records were nematodes or non-food items.

## Empty stomachs live in `ices_stomachs`

A stomach with no prey has no prey record, so it has no row in
`ices_diet`. The companion table `ices_stomachs` has one row per sampled
stomach, empty or not:

``` r

st <- ices_stomachs
st$status <- ifelse(st$stomach_id %in% ices_diet$stomach_id, "with prey records",
             ifelse(st$stomach_empty %in% 1, "flagged empty", "no record, no flag"))
table(st$status)
#> 
#>      flagged empty no record, no flag  with prey records 
#>               1197               3458               4231
table(st$country, st$status)
#>     
#>      flagged empty no record, no flag with prey records
#>   BE            45                  2               195
#>   DE           117                 25               420
#>   DK           595                  7              1861
#>   NL           379                  0               586
#>   NO            61                 30                69
#>   SE             0               3394              1100
```

Of the 8,886 stomachs, 4,231 have at least one record and 1,197 are
flagged empty. The other 3,458 have no record and no flag: almost all
(3,394) are Swedish, and the Swedish data do not report the empty flag,
so these stomachs are most likely empty, but the data do not say so.

This matters for every per-stomach measure. DietView counts the stomachs
it sees, so the denominator of
[`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
is the number of stomachs with at least one record: frequency of
occurrence among feeding fish, not among all fish sampled. For cod,
`ices_stomachs` holds 2,055 stomachs, while the prepared data below hold
991. Use `ices_stomachs` for the proportion of empty stomachs or the
number of fish sampled per stratum.

## Records and counts

A record is not an individual. `prey_count` gives the number of prey
individuals behind each record, when it was reported:

``` r

c(records = nrow(dat), individuals = sum(dat$prey_count, na.rm = TRUE),
  no_count = sum(is.na(dat$prey_count)))
#>     records individuals    no_count 
#>        8530       10816        3468
tapply(is.na(dat$prey_count), dat$item_type, sum)
#>         prey unidentified 
#>         1952         1516
```

Declaring `count` lets you switch from shares of records to shares of
individuals (%N). For cod, the two currencies at class rank:

``` r

cod  <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)
t_rec <- dv_tree(prep_cod)
t_num <- suppressWarnings(dv_tree(prep_cod, currency = "numbers"))
by_rec <- t_rec[t_rec$rank == "Class", ]
by_num <- t_num[match(by_rec$id, t_num$id), ]
cmp <- data.frame(class = by_rec$label, parent = by_rec$parent,
                  records = round(by_rec$pct_occ, 1),
                  numbers = round(by_num$pct_occ, 1))
head(cmp[order(-cmp$records), ], 5)
#>           class              parent records numbers
#> 4  Malacostraca Animalia|Arthropoda    43.4    55.0
#> 7     Teleostei   Animalia|Chordata    27.1    25.9
#> 17           NA               NA|NA     8.3     0.7
#> 8            NA   Animalia|Chordata     6.6     3.0
#> 2    Polychaeta   Animalia|Annelida     6.2     4.9
```

Malacostraca rise from 43.4% of the records to 55.0% of the individuals,
because 20% of the malacostracan records with a count hold more than one
individual. The unidentified material falls out almost entirely: it
rarely has a count, and records without a count contribute nothing to %N
([`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md)
warns, here about 461 cod records). The default currency is records for
that reason.

## Checking a table against a specification

[`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
stops if a declared column is missing, if there is no prey key column,
or if a weight is negative. It warns about records with no prey key,
weights that are not numbers and stomach IDs shared between predators,
and it ends with a one-line description of the sample. It reports
problems and never changes your data. It returns the data invisibly, so
you can use it in a pipeline.

``` r

invisible(dv_validate(dat, spec))
#> 8530 records from 4222 stomachs of 22 predator(s); 2305 stomach(s) hold a single record; 531 record(s) lack a weight.
```

## Mapping your own survey

To use DietView on another table, write a different
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
If your columns were `sp`, `stom`, `aphia`, `wt_g` and `yr`, you would
write:

``` r

spec <- dv_spec(
  predator = "sp", stomach = "stom", prey_id = "aphia",
  weight = "wt_g", covariates = "yr"
)
```

The later steps
([`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
[`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md),
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md))
read the column names from the specification, never from your code. The
article “Adapting DietView to your own survey” goes through the other
choices you make with a new table.
