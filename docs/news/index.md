# Changelog

## DietView 0.1.0

First public release.

### Data model

- [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)
  declares how your columns map to DietView’s roles; nothing is
  hard-coded.
  [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
  checks the table against the spec and reports which currencies and
  diagnostics will be available.

### Taxonomy

- [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  attaches a taxonomic lineage from WoRMS (`"worms"`), from a lineage
  lookup you supply (`"table"`), from existing rank columns
  (`"columns"`), or automatically (`"auto"`). Unresolved prey are kept
  as an explicit `NA` category, never dropped.
- [`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
  resolves prey to WoRMS with an id / exact / fuzzy / unresolved
  strategy, follows unaccepted names to their valid AphiaID, caches to
  disk, and records full provenance.
  [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
  returns the fuzzy and unresolved matches for review.

### Metrics and figures

- [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
  builds the multi-rank tree with within-rank importance in occurrence
  and weight (each rank sums to 100 %, NA included).
- [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
  extracts the importance table for one rank.
- [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)
  renders the multi-rank sunburst with a fixed orientation for
  comparable covariate cells;
  [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
  gives a stable colour dictionary.

### Covariates and diagnostics

- [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
  and
  [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
  derive period and length-bin covariates.
- [`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
  quantifies the identification bias linked to digestion level.

### Outputs

- [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  and
  [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
  render a self-contained HTML dashboard with searchable predator cards;
  [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
  resolves identification photos and descriptions.
- [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  launches an interactive Shiny explorer.
