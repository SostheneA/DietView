# Prey accumulation (cumulative prey) curve for sample sufficiency

Prey richness as a function of the number of stomachs examined, averaged
over random stomach orderings. When the curve approaches an asymptote
the diet has been adequately sampled; a still-rising curve warns that
more stomachs would reveal more prey (Ferry and Cailliet, 1996). This is
a descriptive sufficiency diagnostic, not a statistical test.

## Usage

``` r
dv_prey_accumulation(
  prep,
  by = NULL,
  rank = NULL,
  permutations = 100,
  seed = NULL
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional column giving one curve per group (e.g. the predator). `NULL`
  pools all records into a single curve.

- rank:

  Optional rank (one of `prep$ranks`) at which taxa are counted. `NULL`
  (default) uses the finest resolved label.

- permutations:

  Number of random stomach orderings to average over.

- seed:

  Optional integer for reproducibility. The seed is used for this call
  only: the global random stream is restored on exit.

## Value

A data.frame with (optional) group column, `n_stomachs`, `mean_richness`
and `sd_richness`.

## Details

By default (`rank = NULL`) a taxon is the finest resolved label of each
record. Labels at different ranks can name nested taxa ("Amphipoda" and
*Themisto libellula*), which inflates richness, and the inflation grows
with digestion. Give `rank` to count taxa at one stated rank,
unidentified records excluded.

## Examples

``` r
# the standard set-up: public ICES data, non-food items and nematodes dropped
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
# Atlantic cod only, for speed
cod <- dat[dat$predator_common == "Atlantic cod", ]
prep_cod <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                       verbose = FALSE)
acc <- dv_prey_accumulation(prep_cod, permutations = 20, seed = 1)
head(acc)
#>   n_stomachs mean_richness sd_richness
#> 1          1          1.10   0.4472136
#> 2          2          2.80   1.1050125
#> 3          3          4.20   1.2396944
#> 4          4          5.90   1.3337719
#> 5          5          7.30   1.5927467
#> 6          6          8.45   1.7614288
acc_fam <- dv_prey_accumulation(prep_cod, rank = "family", permutations = 20,
                                seed = 1)
# plot(acc$n_stomachs, acc$mean_richness, type = "b")
```
