# Build a colour dictionary for taxon labels

Every distinct taxon label gets a stable colour; the explicit "NA"
category is always white so identification gaps read as blanks in the
sunburst.

## Usage

``` r
dv_palette(labels, palette = .DV_D3)
```

## Arguments

- labels:

  Character vector of taxon labels (any rank).

- palette:

  Colours to cycle through. Defaults to a d3 category-20 set.

## Value

A named character vector mapping label -\> hex colour.

## Examples

``` r
dv_palette(c("Teleostei", "Malacostraca", "Polychaeta", "NA"))
#>    Teleostei Malacostraca   Polychaeta           NA 
#>    "#1f77b4"    "#aec7e8"    "#ff7f0e"    "#FFFFFF" 
```
