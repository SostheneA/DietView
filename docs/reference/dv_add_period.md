# Derive a period covariate from year

Derive a period covariate from year

## Usage

``` r
dv_add_period(year, breaks, labels = NULL)
```

## Arguments

- year:

  Numeric vector of years.

- breaks:

  Cut points (as in [`base::cut()`](https://rdrr.io/r/base/cut.html)),
  e.g. `c(2003, 2007, 2020)`.

- labels:

  Optional labels; default builds "a-b" style labels.

## Value

A factor of periods.

## Examples

``` r
dv_add_period(c(2004, 2006, 2010, 2018), breaks = c(2003, 2007, 2020))
#> [1] 2003-2007 2003-2007 2007-2020 2007-2020
#> Levels: 2003-2007 2007-2020
```
