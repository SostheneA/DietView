# Build per-group length bins

Cuts a length vector into bins. Use different `breaks` per predator to
merge or split bins where the data warrant it (e.g. `c(0, 20, 30, 40)`).
Labels use interval notation that follows `right`: `[a, b)` for
left-closed bins (the default) and `(a, b]` for right-closed bins.

\[a, b)`for left-closed bins (the default) and`(a, b\]:
R:a,%20b)%60%20for%20left-closed%20bins%20(the%0Adefault)%20and%20%60(a,%20b

## Usage

``` r
dv_size_bins(length, breaks, right = FALSE, labels = NULL)
```

## Arguments

- length:

  Numeric length vector.

- breaks:

  Break edges (ascending).

- right:

  Passed to [`base::cut()`](https://rdrr.io/r/base/cut.html); default
  `FALSE` gives left-closed bins.

- labels:

  Optional labels, one per bin; the default builds interval labels from
  `breaks`.

## Value

A factor of length bins.

## Details

Lengths outside the breaks become `NA`. A covariate `NA` is not a
taxonomic `NA`: the dashboard
([`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md))
omits `NA` strata, while the Shiny app
([`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md))
shows them as an "NA" panel.

## Examples

``` r
dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60))
#> [1] [0, 20)  [20, 30) [30, 40) [40, 60)
#> Levels: [0, 20) [20, 30) [30, 40) [40, 60)
dv_size_bins(c(18, 26, 34, 52), breaks = c(0, 20, 30, 40, 60), right = TRUE)
#> [1] (0, 20]  (20, 30] (30, 40] (40, 60]
#> Levels: (0, 20] (20, 30] (30, 40] (40, 60]
```
