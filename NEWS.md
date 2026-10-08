# DietView 0.1.0

First release.

## Core pipeline
* `dv_spec()`, `dv_validate()`, `dv_prepare()` — column contract, validation,
  and taxonomy resolution against WoRMS or a supplied lineage, with a
  provenance log.
* `dv_build_tree()`, `dv_rank_table()` — within-rank importance in occurrence
  and weight, with unidentified prey kept explicit.
* `dv_sunburst()`, `dv_palette()` — taxonomically complete sunbursts with a
  shared palette and the explicit-NA category in white.
* `dv_add_period()`, `dv_size_bins()` — covariate helpers.
* `dv_digestion_diagnostic()` — the identification-bias diagnostic.
* `dv_species_card_assets()`, `dv_build_html()`, `dv_deploy()`,
  `run_dietview()` — species cards, a self-contained dashboard, deployment,
  and the Shiny explorer.

## Exploration & aggregation
* `dv_summary()` — sample overview by predator and covariate.
* `dv_prey_accumulation()` — cumulative prey curve for sample sufficiency.
* `dv_fo_table()` — classical per-rank frequency of occurrence (percent-F),
  the nested-hierarchy layout; distinct from the additive `pct_occ`.
* `dv_aggregate_threshold()`, `dv_threshold_sweep()` — resolution-robust
  aggregation: collapse prey below a stomach-frequency threshold upward through
  the hierarchy (pooled, cross-predator, and per-predator architectures).
* `dv_matrix()` — sampling-unit by prey-category matrix for downstream
  multivariate analysis.
