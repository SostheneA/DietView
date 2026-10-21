# DietView: interactive, hierarchical visualization of predator stomach-content data

DietView takes a long table of stomach-content records (one row per prey
record), attaches a taxonomic lineage (from WoRMS, or from a lineage
table you supply), and shows the whole diet as an interactive multi-rank
sunburst. Every record reaches every rank: a record identified only to a
coarse rank is kept as an explicit unidentified category below that
rank, so each ring accounts for all the material examined and a parent
equals the sum of its children. Diet is summarized as shares of prey
records (or numbers) and of weight at every rank, alongside the
classical frequency of occurrence. Any declared covariate (period, year,
size class, length bins, region, ...) can stratify the views, and
[`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
describes how identification depth changes with digestion state.

## Details

Main entry points:
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md),
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_tree()`](https://sosthenea.github.io/DietView/reference/dv_tree.md),
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

**Maintainer**: Sosthène A. V. Akia <akiasosthene@gmail.com>

Authors:

- Sosthène A. V. Akia <akiasosthene@gmail.com>

Other contributors:

- CADI Gulf Center \[funder\]
