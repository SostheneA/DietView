# Validate a long table against a spec

Checks that every declared column exists and reports missing
weight/digestion so you know which currencies and diagnostics will be
available.

## Usage

``` r
dv_validate(data, spec, strict_covariates = TRUE)
```

## Arguments

- data:

  A data.frame (the long diet table).

- spec:

  A `dietview_spec` from
  [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).

- strict_covariates:

  If TRUE (default), missing covariates are hard errors. If FALSE, they
  are dropped from `spec$covariates` with a warning.

## Value

`data` invisibly (stops on hard errors, warns on soft gaps).
