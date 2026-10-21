# A known diet: what keeping unidentified prey changes

In a real survey you never know what a predator actually ate; you only
know what could still be identified. This vignette uses an invented
survey in which the true diet is known. Two predators, 150 stomachs
each, eat six prey species with fixed probabilities. Identification is
then degraded with digestion, faster for copepods than for
malacostracans (shrimps, crabs, amphipods) and faster for malacostracans
than for fish. The script that builds the table is
`data-raw/simulate_known_diet.R` in the package’s source repository.

``` r

library(DietView)
f   <- function(x) system.file("extdata", x, package = "DietView")
sim <- read.csv(f("dietview_sim.csv"), na.strings = c("NA", ""))
lin <- read.csv(f("dietview_sim_lineage.csv"), na.strings = c("NA", ""))
spec <- dv_spec(predator = "predator_species_common_name", stomach = "stomach_id",
                prey_name = "verified_name", weight = "prey_weight",
                digestion = "digestion_level_id", covariates = c("period", "region"))
prep <- dv_prepare(sim, spec, taxonomy = "table", lineage = lin, verbose = FALSE)
prep
#> <dietview_prep>
#>   records   : 686 
#>   stomachs  : 300 
#>   predators : 2 
#>   ranks     : kingdom > phylum > class > order > family > genus > species 
#>   covariates: period, region 
#>   source    : table
```

## Three versions of the same diet

For all records pooled, we compare the class composition, by records, in
three ways:

- `truth`: the class of the species each record really was;
- `kept`: what DietView reports, with an unidentified share;
- `dropped`: the common practice of removing unidentified records and
  rescaling the rest to 100%.

``` r

tree <- dv_build_tree(prep$data, prep$ranks, weight_col = "prey_weight")
obs  <- dv_rank_table(tree, "Class")

full_lin   <- read.csv(f("dietview_example_lineage.csv"), na.strings = c("NA", ""))
true_class <- full_lin$class[match(prep$data$true_species, full_lin$verified_name)]
truth      <- 100 * prop.table(table(true_class))

ident <- obs[obs$label != "NA", ]
cmp <- data.frame(class = names(truth), truth = round(as.numeric(truth), 1))
cmp$kept    <- round(ident$pct_occ[match(cmp$class, ident$label)], 1)
cmp$dropped <- round(100 * ident$pct_occ[match(cmp$class, ident$label)] / sum(ident$pct_occ), 1)
cmp <- rbind(cmp, data.frame(class = "unidentified at class", truth = 0,
                             kept = round(sum(obs$pct_occ[obs$label == "NA"]), 1),
                             dropped = NA))
cmp
#>                   class truth kept dropped
#> 1              Copepoda  21.9 17.1    18.6
#> 2          Malacostraca  48.7 45.8    49.9
#> 3             Teleostei  29.4 28.9    31.5
#> 4 unidentified at class   0.0  8.3      NA
```

Three things are worth seeing in this table.

1.  Neither version recovers the truth. Keeping unidentified records
    does not put them back where they belong. It leaves 8.3% of the
    records in a category of its own.
2.  Dropping them shifts the proportions toward prey that keep their
    identity. In this simulation copepods were *set* to lose their
    identity faster than fish, so it is no surprise that they are
    under-represented once unidentified records are removed: the
    direction is an input, not a finding. What the table shows is how
    the rescaled percentages look: complete and precise, with nothing to
    tell the reader that a correction was made.
3.  Keeping them tells you how big the problem could be. When records
    are lost but never misidentified, which is the case here, a class’s
    true share lies between its kept share and its kept share plus the
    unidentified share. That bound is arithmetic, not a result of the
    simulation, and it holds for any survey with the same property. The
    simulation only makes it visible. Dropping the unidentified records
    removes the bound along with them.

## Where the identification was lost

Only in a simulation can we ask which prey ended up unidentified:

``` r

round(100 * tapply(is.na(prep$data$class), true_class, mean), 1)
#>     Copepoda Malacostraca    Teleostei 
#>           22            6            2
```

This is the share of records, for each true class, that could not be
named at class. In real data the same pattern shows up indirectly,
through
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md).
The digestion profile and the unidentified share are what a reader needs
to judge a fine-rank result. On the ICES extract that ships with the
package
([`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md))
there is no `true_species` column to compare with: the unidentified
share by rank and the digestion profile, shown for those data in the
getting-started and digestion vignettes, are all a real survey gives
you.

## What this does and does not show

The simulation is built so that identification loss depends on digestion
and prey class, which is what the diet literature reports (Baker et
al. 2014; Buckland et al. 2017). The direction of the bias is therefore
an assumption, and its size depends on made-up parameters. Neither is a
result, and neither should be quoted. What the vignette demonstrates is
a mechanism: rescaling to the identified fraction hides whatever bias
identification loss introduced, while keeping the unidentified share
shows how large it could be.

To get a size that means something for your own survey, replace the
identification-loss model in `data-raw/simulate_known_diet.R` with rates
estimated from real data. Among records identified at least to class,
the class is known, so a logistic regression of “identified to species”
on digestion score and class gives class-specific loss rates below
class. Loss above class cannot be observed directly; state the
assumption you make about it. The size of the shift is then an estimate
conditional on that stated assumption, and can be reported as such.

## References

Baker, R., Buckland, A., & Sheaves, M. (2014). Fish gut content
analysis: robust measures of diet composition. *Fish and Fisheries*, 15,
170–177.

Buckland, A., Baker, R., Loneragan, N., & Sheaves, M. (2017).
Standardising fish stomach content analysis: the importance of prey
condition. *Fisheries Research*, 196, 126–140.
