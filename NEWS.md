# DietView 0.1.0

First public release.

## Data model
* `dv_spec()` declares how your columns map to DietView's roles; nothing is
  hard-coded. `dv_validate()` checks the table against the spec and reports which
  currencies and diagnostics will be available.

## Taxonomy
* `dv_prepare()` attaches a taxonomic lineage from WoRMS (`"worms"`), from a
  lineage lookup you supply (`"table"`), from existing rank columns
  (`"columns"`), or automatically (`"auto"`). Unresolved prey are kept as an
  explicit `NA` category, never dropped.
* `dv_taxonomy_worms()` resolves prey to WoRMS with an id / exact / fuzzy /
  unresolved strategy, follows unaccepted names to their valid AphiaID, caches to
  disk, and records full provenance. `dv_taxonomy_report()` returns the fuzzy and
  unresolved matches for review.

## Metrics and figures
* `dv_build_tree()` builds the multi-rank tree with within-rank importance in
  occurrence and weight (each rank sums to 100 %, NA included).
* `dv_rank_table()` extracts the importance table for one rank.
* `dv_sunburst()` renders the multi-rank sunburst with a fixed orientation for
  comparable covariate cells; `dv_palette()` gives a stable colour dictionary.

## Covariates and diagnostics
* `dv_add_period()` and `dv_size_bins()` derive period and length-bin covariates.
* `dv_digestion_diagnostic()` quantifies the identification bias linked to
  digestion level.

## Outputs
* `dv_build_html()` and `dv_deploy()` render a self-contained HTML dashboard with
  searchable predator cards; `dv_species_card_assets()` resolves identification
  photos and descriptions.
* `run_dietview()` launches an interactive Shiny explorer.
