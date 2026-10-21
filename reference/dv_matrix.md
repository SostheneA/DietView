# Build a sampling-unit by prey-category matrix

Reshapes the records into a unit x category matrix - the standard input
to multivariate diet analysis (ordination, PERMANOVA, compositional
regression). Rows are the sampling unit (stomachs by default, or any
coarser unit such as a trawl set), columns are prey categories, and
cells carry the chosen currency. DietView does not run those analyses;
this is the handoff to the tools that do.

## Usage

``` r
dv_matrix(
  prep,
  category = NULL,
  unit = NULL,
  rank = NULL,
  currency = c("weight", "occurrence", "fo"),
  include_na = TRUE
)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- category:

  Column giving the prey category. Defaults to `prey_category` (from
  [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md))
  if present, otherwise the finest resolved rank label. Ignored when
  `rank` is given.

- unit:

  Column giving the sampling unit. Defaults to the spec's stomach.

- rank:

  Optional rank (one of `prep$ranks`, e.g. `"class"`): columns are then
  the taxa at that rank, plus the unidentified column (`"NA"`) when
  `include_na = TRUE`.

- currency:

  `"weight"` (summed mass), `"occurrence"` (record counts), or `"fo"`
  (presence/absence, one per unit).

- include_na:

  Keep an explicit unidentified column.

## Value

A numeric matrix with `unit` row names and category column names.

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
m <- dv_matrix(prep_cod, currency = "occurrence")
dim(m)
#> [1] 991 145
m_class <- dv_matrix(prep_cod, rank = "class", currency = "weight")
m_class[1:5, 1:4]
#>         Bivalvia Cephalopoda Gastropoda Gephyrea
#> S162741        0           0          0        0
#> S162742        0           0          0        0
#> S162743        0           0          0        0
#> S162744        0           0          0        0
#> S162745        0           0          0        0
# vegan::decostand(m, "total"); vegan::vegdist(m, "bray")
```
