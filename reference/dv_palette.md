# Build a color dictionary for taxon labels

Every distinct taxon label gets a color, and the same label gets the
same color in every panel built from one dictionary. The palette cycles
after 20 colors, so in a large survey several taxa share a color; see
[`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
for colors that follow the hierarchy. The unidentified (`"NA"`) category
is always white; the sunburst draws a gray outline around every wedge so
white wedges stay visible.

## Usage

``` r
dv_palette(labels, palette = .DV_D3)
```

## Arguments

- labels:

  Character vector of taxon labels (any rank).

- palette:

  Colors to cycle through. Defaults to a d3 category-20 set.

## Value

A named character vector mapping label -\> hex color.

## Examples

``` r
dv_palette(c("Teleostei", "Malacostraca", "Polychaeta", "NA"))
#>    Teleostei Malacostraca   Polychaeta           NA 
#>    "#1f77b4"    "#aec7e8"    "#ff7f0e"    "#FFFFFF" 
```
