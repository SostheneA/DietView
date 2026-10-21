# Changelog

## DietView (development version)

### Example data

- Three datasets of real, public stomach-content data, from the ICES
  Stomach Content Database (ICES, Copenhagen), as extracted in the R
  package stomachr (Lindmark 2026); see
  [`?ices_diet`](https://sosthenea.github.io/DietView/reference/ices_diet.md):
  - `ices_diet`: 9,639 prey records from 4,231 stomachs of 22 fish
    species, North Sea, Skagerrak-Kattegat and Baltic Sea, 2020-2024,
    one row per prey record, in the format DietView expects;
  - `ices_stomachs`: the 8,886 sampled stomachs, one row each, the 1,197
    empty ones included;
  - `ices_lineage`: the frozen WoRMS classification of the 461 prey
    keys, for an offline, reproducible `dv_prepare(taxonomy = "table")`.

  Rows that only mark an empty stomach in the ICES export were dropped,
  and two unit errors in the predator variables were fixed (Belgian
  lengths reported in mm, Danish individual weights reported in kg).
  Everything else is kept as exported, including unidentified material,
  Nematoda (mostly parasites) and non-food items, so the data show what
  real surveys look like; the analyst decides what to drop. The
  digestion labels are inferred from the older ICES format.
- The examples, the README, the vignettes and the website articles now
  use the ICES data instead of the invented example. A new article,
  “Case study: a complete analysis of public ICES stomach data”, works
  through a full analysis of them.
- The small 24-record example (`inst/extdata/dietview_example.csv` and
  its lineage table) is kept for the tests and for quick checks of the
  mechanics.
- [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
  gains an example.

### Bug fixes

- `dv_prepare(taxonomy = "worms")` no longer stops with “arguments imply
  differing number of rows” when some records have no AphiaID (as in the
  bundled example). Each record is now keyed by its AphiaID, or by its
  own prey name when it has none, so records without an AphiaID no
  longer share one lineage, and the provenance log counts every record
  once. One AphiaID recorded under several spellings no longer errors;
  the log lists the names seen under each key (`names_seen`).
- Failed WoRMS lookups are no longer cached; empty lineages cached by
  0.1.0 are discarded. A prey that was matched but got no classification
  (network or server error, unknown AphiaID) is flagged with
  `lineage_ok = FALSE`, reported by a warning and by
  [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md),
  and retried on the next run. The cache is saved even when a run is
  interrupted.
- Known AphiaIDs are now checked against WoRMS: unaccepted AphiaIDs are
  followed to their accepted one (`match_type = "id_synonym"`), the
  stored prey name is compared with the WoRMS name (`name_check`), and
  an AphiaID whose record cannot be read is marked `"id_unchecked"`.
- Fuzzy name matching now uses WoRMS TAXAMATCH
  ([`worrms::wm_records_taxamatch()`](https://docs.ropensci.org/worrms/reference/wm_records_taxamatch.html)),
  which tolerates misspellings, instead of a prefix (LIKE) search. Names
  with several accepted WoRMS records are flagged (`homonym`), and the
  number of records WoRMS returned is logged (`n_candidates`).
- The exact WoRMS name search no longer passes a `fuzzy` argument that
  current `worrms` (0.4.x) does not have and handed to the HTTP client,
  which made every exact name lookup fail.
- `dv_prepare(taxonomy = "table")` now stops on duplicated keys in the
  lineage table, warns about prey keys absent from it, and no longer
  lets a record without a key inherit the lineage of a lineage row
  without a key.
- [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md)
  now guarantees that every reported category is found in at least
  `threshold` stomachs: a residual category below the threshold moves up
  one more rank. Residuals of a node that also has retained descendants
  are labelled `"<taxon> (other)"`, and the default `other_label` is now
  `"other (below threshold)"`.
- `dv_validate(strict_covariates = FALSE)` now really drops the missing
  covariates: the corrected spec is returned as the `dv_spec` attribute,
  and
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  gains `strict_covariates` and uses it.
- `dv_prey_accumulation(seed = )` no longer changes the user’s random
  stream.
- [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  no longer assumes a “class” rank for its default table.
- [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  writes titles containing quotes or apostrophes correctly.

### Changes in behavior

- One definition of the record currency everywhere:
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  and
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  now count prey records by default, even when the spec declares
  `count`, and gain `currency = c("records", "numbers")`. New
  `dv_tree(prep, currency)` builds the tree from a prepared dataset the
  same way. The numbers currency warns that records without a count
  (usually unidentified material) contribute 0.
- [`dv_validate()`](https://sosthenea.github.io/DietView/reference/dv_validate.md)
  now checks prey keys (AphiaIDs must be positive whole numbers; records
  with no usable key are reported), weights (negative weights are an
  error, non-numeric ones a warning), the number of digestion levels,
  and stomach IDs shared between predators. It prints a one-line summary
  of the sample (records, stomachs, predators, single-record stomachs,
  missing weights) and returns the counts as the `dv_report` attribute;
  `quiet = TRUE` silences the messages. A missing weight column is now a
  message, not a warning.
- [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  stores `taxonomy_source`, and its print method shows the number of
  stomachs and the taxonomy source. The WoRMS log records the retrieval
  time and the `worrms` version (attributes `retrieved`,
  `worrms_version`) and the date each lineage was fetched (`retrieved`
  column).
- WoRMS cache entries now carry a date; entries older than
  `cache_max_age` days (new argument of
  [`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
  and
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
  default 180) are fetched again. Undated entries written by 0.1.0 are
  fetched again once.
- `dv_taxonomy_report(which = "review")` also lists `id_synonym`,
  `id_unchecked`, name disagreements, possible homonyms and failed
  classifications.
- [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  has no default `output` any more, and defaults to no network access
  and an image folder in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html), so a default call
  touches neither the network nor the working directory.
  [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
  has the same new defaults.
- Predator photos can now come from iNaturalist:
  `photo_source = "inaturalist"` in
  [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md),
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  and
  [`dv_deploy()`](https://sosthenea.github.io/DietView/reference/dv_deploy.md).
  Only photos whose license is in `licenses` are used (default CC0, CC
  BY, CC BY-SA; “all rights reserved” photos never), and only for a
  taxon whose name matches the query. `photo_source = "wikipedia"` keeps
  the Wikipedia / Wikimedia Commons lookup, which now uses only Commons
  files with a known license. `use_wiki` is deprecated (`TRUE` means
  `"wikipedia"`, `FALSE` means `"none"`). Several sources can be given,
  tried in order, e.g. `photo_source = c("inaturalist", "wikipedia")`;
  each request times out after `getOption("DietView.timeout", 15)`
  seconds, and the result includes the image file (`path`), so other
  tools (such as a web export) can reuse it.
- Every card photo carries its author and license:
  [`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
  returns `credit`, `author`, `license`, `source` and `url`, and the
  dashboard shows the credit under the photo, linked to the photo’s
  page. The Wikipedia text used as a description is credited too
  (`desc_credit`). Credit fields can be given for your own photos in
  `species_info`.
- Downloaded photos are saved with a `.json` file holding their credit,
  so a cached photo keeps its author and license in later sessions (in
  0.1.0 a cached photo lost its credit line).
- Sunbursts are sized from leaf values with
  `branchvalues = "remainder"`, so a parent always equals the sum of its
  children; every wedge has a thin gray outline so white (unidentified)
  wedges stay visible, and the hover text says “Not identified at this
  rank”. Unidentified nodes are placed last within each parent in
  [`dv_build_tree()`](https://sosthenea.github.io/DietView/reference/dv_build_tree.md)
  output, which also carries a `currency` attribute.
- New
  [`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md):
  one hue per node at a chosen rank, lighter tints for its descendants,
  keyed by node id. `dv_sunburst(colors = )` accepts colors keyed by
  node id or by label.
- Display vocabulary: “Prey records (% of all records)”, “Weight (% of
  total weight)” and “Distinct prey items” replace “Occurrence counts”,
  “Occurrence %” and “Distinct diet counts” in the app and the
  dashboard. The `mode = "occurrence"` value is unchanged.
- [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
  and
  [`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md)
  gain `rank`, to count taxa at one stated rank instead of the finest
  resolved label (which mixes ranks and inflates richness).
  [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)’s
  `prey_per_stomach` column is renamed `records_per_stomach`.
- [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
  gains `rank`, for a sample-by-taxon matrix at a chosen rank.
- [`dv_size_bins()`](https://sosthenea.github.io/DietView/reference/dv_size_bins.md)
  labels follow `right` and use interval notation (`[40, 50)` rather
  than `[40-50[`); it gains `labels`. The example data’s `size_bin`
  column uses the new labels.
- [`dv_add_period()`](https://sosthenea.github.io/DietView/reference/dv_add_period.md)
  labels name the years each period contains (`2003-2007`, `2008-2020`
  rather than `2003-2007`, `2007-2020`).
- [`dv_threshold_sweep()`](https://sosthenea.github.io/DietView/reference/dv_threshold_sweep.md)
  reports `pct_coarser` (share of records whose category is coarser than
  the finest rank) instead of the constant `n_records`.

### Documentation and metadata

- New title: “Interactive, Hierarchical Visualization of Stomach-Content
  Data”; new Description, author name split correctly (with ORCID
  placeholder), CADI Gulf Center listed as funder, unused packages
  removed from Suggests; `inst/CITATION` and `CITATION.cff` updated.
- “Taxonomically complete” replaced by “hierarchical” throughout.
- The data dictionary states that the example data are invented, defines
  the weight and digestion scale, and requires stomach IDs to be unique
  across the whole table.
- New tests cover the tree invariants, frequency of occurrence, the
  digestion diagnostic, threshold aggregation, the matrix, validation,
  the lineage-table join, covariate labels and the WoRMS path (with
  mocked `worrms` calls).
- Internal notes (`CRAN_SUBMISSION.md`, `DEPLOYMENT.md`) moved to `dev/`
  and no longer published on the website.

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
  — hierarchical sunbursts with a shared palette and the explicit-NA
  category in white.
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
