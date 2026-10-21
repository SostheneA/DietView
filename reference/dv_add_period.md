# Derive a period covariate from year

Cuts whole years into periods. The first period includes its lower
break; every later period starts the year after the previous break, so
with `breaks = c(2003, 2007, 2020)` the periods are 2003-2007 and
2008-2020, and each label names the years the period actually contains.

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

  Optional labels; the default builds "first-last" labels from the years
  each period contains.

## Value

A factor of periods. Years outside the breaks become `NA`.

## Examples

``` r
dv_add_period(c(2004, 2006, 2010, 2018), breaks = c(2003, 2007, 2020))
#> [1] 2003-2007 2003-2007 2008-2020 2008-2020
#> Levels: 2003-2007 2008-2020
```
