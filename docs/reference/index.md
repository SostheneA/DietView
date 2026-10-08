# Package index

## Package overview

What DietView is and how the pieces fit together.

- [`DietView`](https://sosthenea.github.io/DietView/reference/DietView-package.md)
  [`DietView-package`](https://sosthenea.github.io/DietView/reference/DietView-package.md)
  : DietView: taxonomically complete visualization of diet data

## 1 · Declare and validate your data

Describe once how your columns map to DietView’s roles. Nothing is
hard-coded; every other function reads this spec.

- [`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)
  : Declare how your columns map to DietView's roles
- [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
  : Validate a long table against a spec

## 2 · Attach taxonomy

Resolve prey to the WoRMS classification (or join your own lineage),
keeping unresolved prey as an explicit NA category and logging every
match for review.

- [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  : Prepare a diet table for DietView (validate + add taxa)
- [`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
  : Resolve prey to the WoRMS classification (exact, then optional
  fuzzy)
- [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md)
  : Review fuzzy and unresolved prey matches

## 3 · Build covariates

Derive periods and length bins to stratify the views.

- [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
  : Derive a period covariate from year
- [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
  : Build per-group length bins

## 4 · Compute within-rank importance

Aggregate records into a multi-rank tree where each rank sums to 100
percent, NA included, in both occurrence and weight currencies.

- [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
  : Build the multi-rank tree with within-rank importance
- [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
  : Importance table for one rank

## 5 · Draw figures

Render the multi-rank sunburst and the stable colour dictionary.

- [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)
  : Render a diet sunburst
- [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
  : Build a colour dictionary for taxon labels

## 6 · Quantify the digestion identification bias

- [`dv_digestion_diagnostic()`](https://sosthenea.github.io/DietView/reference/dv_digestion_diagnostic.md)
  : Identification resolution versus digestion level

## 7 · Species identification cards

- [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
  : Resolve an identification photo and description for a predator

## 8 · Ship a dashboard or explore interactively

A self-contained HTML dashboard, a deploy wrapper, and a Shiny explorer.

- [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  : Build a self-contained HTML diet dashboard
- [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md)
  : Deploy the dashboard as a standalone HTML file
- [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  : Launch the interactive DietView app

## 9 · Explore, aggregate, and export

Describe the sample, check sampling sufficiency, report classical
frequency of occurrence, aggregate rare prey upward to a reproducible
threshold, and export the sampling-unit by prey-category matrix for
downstream multivariate analysis.

- [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
  : Describe the sampled diet dataset
- [`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
  : Prey accumulation (cumulative prey) curve for sample sufficiency
- [`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
  : Frequency of occurrence per rank (the Buckland Table B1 layout)
- [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
  : Aggregate rare prey upward to a stomach-frequency threshold
- [`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.md)
  : Count diet categories across a sweep of thresholds
- [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
  : Build a sampling-unit by prey-category matrix
