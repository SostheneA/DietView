# Reshape a wide sample-by-taxon table into DietView's long format

DNA metabarcoding (ASV/OTU tables), catch composition and many survey
tables come wide: one row per taxon and one column per sample, or the
reverse. `dv_from_wide()` turns them into the long table DietView
expects, one row per taxon in a sample, and joins the sample metadata
(predator, covariates) so the result goes straight into
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)
and
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

## Usage

``` r
dv_from_wide(
  x,
  taxa_in = c("rows", "columns"),
  id_cols,
  sample_col = "sample",
  value_col = "reads",
  taxon_col = "prey_name",
  meta = NULL,
  drop_zero = TRUE,
  collapse_by = NULL
)
```

## Arguments

- x:

  A data.frame.

- taxa_in:

  `"rows"` (default; one row per taxon, one column per sample, the usual
  ASV/OTU table) or `"columns"` (one row per sample, one column per
  taxon).

- id_cols:

  Columns that are not counts: with `taxa_in = "rows"`, the columns
  describing the taxon (ASV id, lineage string, rank columns ...); with
  `taxa_in = "columns"`, the columns describing the sample. Every other
  column is read as counts.

- sample_col:

  Name of the sample column in the result (with `taxa_in = "columns"`,
  it must be one of `id_cols`). Use it as `dv_spec(stomach = )`.

- value_col:

  Name of the value column in the result (e.g. `"reads"`), for
  `dv_spec(weight = )` or `dv_spec(count = )`.

- taxon_col:

  With `taxa_in = "columns"`, the name of the column that receives the
  taxon names (the former column names).

- meta:

  Optional data.frame of sample metadata (predator, date, area, ...),
  joined by `sample_col`. A sample without metadata is kept, with a
  warning.

- drop_zero:

  Drop records whose value is 0 or missing (default `TRUE`).

- collapse_by:

  Optional columns defining one prey; rows sharing a sample and these
  columns are summed into one record.

## Value

A long data.frame: the taxon columns, `sample_col`, `value_col` and the
metadata columns.

## Details

Records with a zero or missing value are dropped (`drop_zero = TRUE`),
as a prey absent from a sample is not a prey record. With `collapse_by`,
the values of the rows that share a sample and the same `collapse_by`
columns (e.g. several ASVs assigned to the same species) are summed into
one record, so that shares of prey records and %FO count a taxon once
per sample.

## See also

[`dv_parse_lineage()`](https://sosthenea.github.io/DietView/reference/dv_parse_lineage.md)
to split a lineage string into ranks.

## Examples

``` r
# an ASV table: one row per ASV, one column per scat sample
asv <- data.frame(
  asv = c("a1", "a2", "a3"),
  taxonomy = c("k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
               "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
               "k__Animalia;p__Arthropoda;c__Malacostraca;o__Euphausiacea;f__;g__;s__"),
  S1 = c(120, 30, 0), S2 = c(0, 0, 400))
meta <- data.frame(sample = c("S1", "S2"), predator = "grey seal",
                   season = c("winter", "summer"))
long <- dv_from_wide(asv, id_cols = c("asv", "taxonomy"), meta = meta,
                     collapse_by = "taxonomy")
long <- dv_parse_lineage(long, "taxonomy")
spec <- dv_spec(predator = "predator", stomach = "sample",
                prey_name = "prey_name", weight = "reads",
                weight_type = "rra", covariates = "season")
prep <- dv_prepare(long, spec, taxonomy = "columns", verbose = FALSE)
dv_rank_table(dv_tree(prep), "Phylum")
#>        label value_item value_occ pct_occ value_w pct_w
#> 2 Arthropoda          1         1      50       1    50
#> 3   Chordata          1         1      50       1    50
```
