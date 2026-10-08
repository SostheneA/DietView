# Changelog

## DietView 0.1.0

First release.

### Core pipeline

- [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md),
  [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md),
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  — column contract, validation, and taxonomy resolution against WoRMS
  or a supplied lineage, with a provenance log.
- [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md),
  [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
  — within-rank importance in occurrence and weight, with unidentified
  prey kept explicit.
- [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md),
  [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
  — taxonomically complete sunbursts with a shared palette and the
  explicit-NA category in white.
- [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md),
  [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
  — covariate helpers.
- [`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
  — the identification-bias diagnostic.
- [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md),
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md),
  [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md),
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  — species cards, a self-contained dashboard, deployment, and the Shiny
  explorer.

### Exploration & aggregation

- [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
  — sample overview by predator and covariate.
- [`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
  — cumulative prey curve for sample sufficiency.
- [`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
  — classical per-rank frequency of occurrence (percent-F), the
  nested-hierarchy layout; distinct from the additive `pct_occ`.
- [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md),
  [`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.md)
  — resolution-robust aggregation: collapse prey below a
  stomach-frequency threshold upward through the hierarchy (pooled,
  cross-predator, and per-predator architectures).
- [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
  — sampling-unit by prey-category matrix for downstream multivariate
  analysis.
