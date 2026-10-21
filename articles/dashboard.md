# Building a self-contained diet dashboard

[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
writes a single HTML file with one page per predator, modeled on the
diet dashboard built for the southern Gulf of St. Lawrence. The landing
page shows one card per predator, with its stomach count and, if you
give a length column, its length range. Each predator page shows the
diet in up to three bands: distinct prey items, prey records (% of all
records) and weight (% of total weight). Every band has the same layout:
one sunburst for all the predator’s records, one row of sunbursts per
covariate you choose, and, if you ask for them, crossed rows.

The data are the public ICES stomach-content extract that ships with the
package (ICES Stomach Content Database, ICES, Copenhagen; extract
distributed with the R package stomachr, Lindmark 2026; see
[`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md)).
The preparation chunks run; the chunks that write HTML files are shown
but not run, because a dashboard of this size takes a while to build.

## Preparing the data

The set-up is the one used in every vignette, restricted here to the
four predators with the most records, so that each page has enough
stomachs per panel:

``` r

library(DietView)

# drop non-food items and nematodes (mostly parasites, not prey)
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]

top <- c("Atlantic cod", "Whiting", "European plaice", "Atlantic mackerel")
dat <- dat[dat$predator_common %in% top, ]
```

### Length classes, predator by predator

Diets change with predator size, so length is the first stratum most
people want. One set of length classes does not fit four predators of
different sizes: a 25 cm mackerel is a small fish, a 25 cm cod a young
one.
[`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
cuts lengths with breaks you choose, so give each predator its own:

``` r

tapply(dat$length_cm, dat$predator_common, range)
#> $`Atlantic cod`
#> [1]   6 104
#> 
#> $`Atlantic mackerel`
#> [1] 17.7 45.2
#> 
#> $`European plaice`
#> [1] 11 54
#> 
#> $Whiting
#> [1]  9 44

breaks <- list(
  "Atlantic cod"      = c(0, 20, 30, 40, 50, 110),
  "Whiting"           = c(0, 20, 25, 30, 45),
  "European plaice"   = c(0, 20, 25, 30, 55),
  "Atlantic mackerel" = c(0, 25, 30, 35, 50)
)
dat$length_class <- NA_character_
for (p in names(breaks)) {
  i <- dat$predator_common == p
  dat$length_class[i] <- as.character(dv_size_bins(dat$length_cm[i], breaks[[p]]))
}
```

Check the number of stomachs per class before you build anything; a
sunburst from a handful of stomachs is not worth drawing:

``` r

stom <- unique(dat[, c("stomach_id", "predator_common", "length_class",
                       "region", "quarter")])
lapply(split(stom$length_class, stom$predator_common), table)
#> $`Atlantic cod`
#> 
#>   [0, 20)  [20, 30)  [30, 40)  [40, 50) [50, 110) 
#>       208       299       257       109       118 
#> 
#> $`Atlantic mackerel`
#> 
#>  [0, 25) [25, 30) [30, 35) [35, 50) 
#>      260      240      307      241 
#> 
#> $`European plaice`
#> 
#>  [0, 20) [20, 25) [25, 30) [30, 55) 
#>      153      197      189      190 
#> 
#> $Whiting
#> 
#>  [0, 20) [20, 25) [25, 30) [30, 45) 
#>      256      265      220      151
```

The breaks above were chosen so that every class holds at least a
hundred stomachs. Move them, or merge classes, where your data are
thinner.

### Region and quarter

The other two strata are region and quarter. They are not balanced:

``` r

table(stom$predator_common, stom$region)
#>                    
#>                     Baltic Sea North Sea Skagerrak-Kattegat
#>   Atlantic cod             198       731                 62
#>   Atlantic mackerel          0       948                100
#>   European plaice           38       429                262
#>   Whiting                  167       650                 75
table(stom$predator_common, stom$quarter)
#>                    
#>                        1    2    3    4
#>   Atlantic cod       570    0   97  324
#>   Atlantic mackerel    0 1048    0    0
#>   European plaice    168    0  561    0
#>   Whiting            551    0  276   65
```

Mackerel were sampled in quarter 2 only and never in the Baltic Sea;
plaice in quarters 1 and 3. The dashboard omits empty strata, so the
mackerel page simply has one quarter panel. On the global page, which
pools the four predators, a comparison across quarters or regions is
also a comparison of whichever predators were sampled there, and with
these data of the countries that sampled them. The same goes for length:
the global page puts every predator’s class with the same label in one
panel (`[0, 20)` holds small cod, plaice and whiting), so read length on
the predator pages.

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
  covariates     = c("region", "quarter", "length_class")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 7392 
#>   stomachs  : 3660 
#>   predators : 4 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: region, quarter, length_class 
#>   source    : table
```

## The simplest dashboard

Name the output file yourself. By default the build stays offline, so
the cards have no photo:

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"))
```

## Stratifying each band by covariates

`strata` picks the covariates that get their own row of sunbursts in
every band. `cross` adds crossed rows: `cross = list(c(inner, outer))`
gives one row per level of `outer`, with one sunburst per level of
`inner` in that row.

``` r

dv_build_html(
  prep,
  output = file.path(tempdir(), "diet_dashboard.html"),
  strata = c("region", "quarter", "length_class"),
  cross  = list(c("length_class", "region")),   # length classes within regions
  bands  = c("count", "occurrence", "weight"),
  length_col = "length_cm"
)
```

In `bands`, `"count"` is the distinct prey items band, `"occurrence"`
the prey records band and `"weight"` the weight band. Crossing
multiplies the number of panels: five cod length classes in three
regions give up to fifteen sunbursts per band, and some of them rest on
few stomachs (see `stom` above). Each panel prints its stomach count;
read it before the sunburst. With these four predators and this
crossing, the file holds several hundred sunbursts: it took about a
minute to build and weighs about 20 MB. Drop a band or the crossing for
a lighter file.

To show individuals (%N) rather than records in the second band, add
`currency = "numbers"`. Records without a count, which here include
almost all the unidentified material, then contribute nothing to that
band.

## Identification cards

Each predator card can show a photo and a short description. DietView
looks for a photo in this order: a local file you name in
`species_info`, a local file in `image_dir` named after the predator or
its Latin name, then, if you ask for it, an openly licensed photo from
iNaturalist (`photo_source = "inaturalist"`) or from Wikipedia and
Wikimedia Commons (`photo_source = "wikipedia"`). The photo is embedded
in the HTML file, so the file stays complete on its own. To control what
is shown, supply your own description and photo:

``` r

info <- list(
  "Atlantic cod" = list(
    desc  = "Demersal gadid; feeds on crustaceans and fish.",
    photo = "images/atlantic_cod.jpg"
  )
)
dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"),
              species_info = info, image_dir = "images")
```

To fill the cards from iNaturalist, the predators’ Latin names must be
in the spec; `ices_diet` has them in `predator_latin` (for example
*Gadus morhua*, *Merlangius merlangus*). Then ask for that source:

``` r

dv_build_html(prep, output = file.path(tempdir(), "diet_dashboard.html"),
              strata = c("region", "quarter", "length_class"),
              length_col = "length_cm",
              photo_source = "inaturalist",
              image_dir = file.path(tempdir(), "dietview-images"))
```

This needs an internet connection. Only photos under CC0, CC BY or CC
BY-SA are used unless you widen `licenses`, and each card shows the
photographer and the license, linked to the photo’s page on iNaturalist.
Keep those credits: they are the condition under which the photos may be
reused. Check the credit line on each card before you share the file.
The article on species cards gives the details.

## Deploying to a folder

[`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
calls
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
and writes the file into a folder of your choice, for example one served
by your web platform. It returns the path.

``` r

dv_deploy(prep, file = "dietview_dashboard.html",
          dir = file.path(tempdir(), "outputs"),
          strata = c("region", "quarter", "length_class"),
          cross  = list(c("length_class", "region")),
          length_col = "length_cm")
```

The dashboard is a snapshot. It holds the data as they were when you
built it, opens in any browser and needs neither R nor an internet
connection. Say on the page, or next to it, where the data come from:
here “ICES Stomach Content Database, ICES, Copenhagen”.
