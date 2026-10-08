# Build per-group length bins

Cuts a length vector into bins. Use different `breaks` per predator to
merge or split bins where the data warrant it (e.g. `c(0, 20, 30, 40)`).
Labels are auto-built as "\[a-b\[".

## Usage

``` r
dv_size_bins(length, breaks, right = FALSE)
```

## Arguments

- length:

  Numeric length vector.

- breaks:

  Break edges (ascending). Rows outside the range become `NA`.

- right:

  Passed to [`base::cut()`](https://rdrr.io/r/base/cut.html); default
  `FALSE` gives left-closed bins.

## Value

A factor of length bins.

## Examples

``` r
dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60))
#> [1] [0-20[  [20-30[ [30-40[ [40-60[
#> Levels: [0-20[ [20-30[ [30-40[ [40-60[
```
