# Declare how your columns map to DietView's roles

DietView never hard-codes column names. You describe your long table
once with `dv_spec()`, then pass the spec to every other function. One
row of the table must be one prey record in a stomach.

## Usage

``` r
dv_spec(
  predator,
  stomach,
  prey_name = NULL,
  prey_id = NULL,
  weight = NULL,
  count = NULL,
  digestion = NULL,
  covariates = character(0),
  ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
  predator_latin = NULL,
  weight_type = c("mass", "reads", "rra"),
  unit_label = "stomach"
)
```

## Arguments

- predator:

  Column with the predator name/species.

- stomach:

  Column with the stomach identifier (unit of occurrence). It must be
  unique across the whole table, not only within a predator.

- prey_name:

  Column with the prey latin name (used if `prey_id` is missing).

- prey_id:

  Column with the WoRMS AphiaID of the prey (preferred key).

- weight:

  Column with prey weight (for the weight currency). Optional.

- count:

  Column with the number of prey individuals. Optional. It is used only
  when an output is asked for the numbers currency
  (`currency = "numbers"` in
  [`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md),
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  and
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md));
  otherwise each record counts once.

- digestion:

  Column with the digestion level (enables digestion diagnostics).
  Optional.

- covariates:

  Character vector of covariate columns to allow as strata (e.g.
  `c("period", "year", "size_class")`).

- ranks:

  Taxonomic ranks to display, coarse to fine. Defaults to the seven
  flagship ranks kingdom..species. If your table already carries these
  columns, keep the default; otherwise they are filled by
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- predator_latin:

  Optional column with the predator Latin name (used to look up
  identification photos when
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  is given a `photo_source`).

- weight_type:

  What the `weight` column measures:

  - `"mass"` (default): prey mass; the weight views show %W;

  - `"reads"`: sequence reads (DNA metabarcoding); the weight views show
    the pooled share of all reads;

  - `"rra"`: sequence reads, turned into relative read abundance by
    [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md):
    the reads of each sample (the `stomach` column) are divided by the
    sample total, so every sample weighs the same and the weight share
    at a rank is the mean RRA over samples (Deagle et al. 2019,
    Molecular Ecology 28: 391-406). The raw reads are kept and the
    proportions are added as a new column.

  With reads, `stomach` is still the sampling unit (a stomach, a scat, a
  pellet, a sample); `count` and `digestion` are usually absent.

- unit_label:

  What one `stomach` is, for messages, the dashboard and the Shiny app:
  `"stomach"` (default), `"scat"`, `"sample"`, `"haul"`... Give one
  word, or `c(singular, plural)` when the plural is not formed with an
  "s". Argument and column names (`stomachs =`, `min_stomachs`,
  `n_stomachs`) do not change.

## Value

An object of class `dietview_spec`.

## Examples

``` r
# the column roles of the public ICES data (see ?ices_diet)
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
spec$ranks
#> [1] "kingdom" "phylum"  "class"   "order"   "family"  "genus"   "species"
```
