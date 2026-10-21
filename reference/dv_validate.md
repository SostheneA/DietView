# Check a long diet table against a spec before any work is done

Stops on problems DietView cannot work around (a declared column is
missing, there is no prey key, a weight is negative) and warns about the
ones that change what the figures mean (prey keys that are not AphiaIDs,
records with no prey key, weights that are not numbers, stomach IDs
shared between predators). It then prints a one-line description of the
sample. It reports; it does not repair.

## Usage

``` r
dv_validate(data, spec, strict_covariates = TRUE, quiet = FALSE)
```

## Arguments

- data:

  A data.frame, one row per prey record.

- spec:

  A `dietview_spec` from
  [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).

- strict_covariates:

  If `TRUE` (default) a declared covariate missing from `data` is an
  error; if `FALSE` it is dropped from the spec with a warning.

- quiet:

  Suppress the summary and the informational messages (warnings and
  errors are never suppressed).

## Value

`data`, invisibly, with two attributes: `dv_spec` (the spec, minus any
dropped covariates) and `dv_report` (a list of counts).

## Details

A missing weight or digestion column is not an error: it only disables
the weight views or the digestion diagnostic, and is reported as a
message.
