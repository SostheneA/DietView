# DietView: taxonomically complete visualization of diet data

DietView takes a long table of stomach-content records (one row per prey
record), resolves prey to the WoRMS classification, and renders the
whole diet as an interactive multi-rank sunburst. Relative importance is
computed in two currencies (occurrence and weight) as the share of each
taxon within its own taxonomic rank, keeping unidentified prey as an
explicit "NA" category so the identification gaps are visible rather
than hidden. Any number of covariates (period, year, size class, length
bins, region, ...) can stratify the views, and the identification bias
linked to digestion level is quantified explicitly.

## Details

Main entry points:
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md),
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
[`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md),
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md),
[`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md),
[`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md).

## See also

Useful links:

- <https://github.com/SostheneA/DietView>

- <https://sosthenea.github.io/DietView/>

- Report bugs at <https://github.com/SostheneA/DietView/issues>

## Author

**Maintainer**: Sosthene A. V. Akia <akiasosthene@gmail.com>

Authors:

- Sosthene A. V. Akia <akiasosthene@gmail.com>

- CADI Gulf Center \[copyright holder\]
