# Changelog

## DietView 0.1.0.9000

### Breaking changes

- [`dv_sunburst()`](https://sosthenea.github.io/DietView/reference/dv_sunburst.md)
  now sizes wedges by prey records by default (`mode = "occurrence"`);
  the choices are ordered `"occurrence"`, `"weight"`, `"count"`, as in
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md).
- [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  draws the record and weight bands by default
  (`bands = c("occurrence", "weight")`); add `"count"` for distinct prey
  items.
- Default colors follow the hierarchy:
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md),
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  and the script of
  [`dv_script()`](https://sosthenea.github.io/DietView/reference/dv_script.md)
  use
  [`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
  built from the pooled tree of the whole prepared dataset, and
  `dv_sunburst(colors = NULL)` uses
  [`dv_palette_tree()`](https://sosthenea.github.io/DietView/reference/dv_palette_tree.md)
  of the tree drawn. A taxon keeps one color across panels and
  neighbouring wedges no longer share a color.
  [`dv_palette()`](https://sosthenea.github.io/DietView/reference/dv_palette.md)
  is still exported for label-keyed colors.
- [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md),
  [`run_dietview()`](https://sosthenea.github.io/DietView/reference/run_dietview.md)
  and
  [`dv_script()`](https://sosthenea.github.io/DietView/reference/dv_script.md)
  share one argument for missing covariate values,
  `na_strata = c("drop", "show")`. The default leaves records with a
  missing value out of that covariate’s panels (the dashboard’s
  behaviour); `"show"` gives them an “NA” panel (the app’s previous
  behaviour, now opt-in).

### Other changes

- WoRMS lookups are batched and retried.
  [`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
  reads records and matches names in chunks
  (`getOption("DietView.worms_chunk", 50)`) instead of one request per
  prey, retries a failed request up to
  `getOption("DietView.worms_retries", 3)` times with backoff (1, 2, 4
  s), and reads “no match” from the HTTP status when the condition
  carries it (worrms 0.4 only gives it in the message, which stays the
  fallback). An AphiaID that WoRMS does not know falls back to the prey
  name, logged as `match_type = "id_fallback_name"` and listed by
  [`dv_taxonomy_report()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_report.md).
- [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  gains `stomachs` (one row per examined stomach, empty ones included,
  e.g. `ices_stomachs`) and `empty_col` (the empty flag), stored in
  `prep$stomachs`. With it,
  [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md)
  adds `n_examined`, `n_empty` and `pct_vacuity`;
  [`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md)
  gains `denominator = c("nonempty", "examined")`; and
  [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
  gains `include_empty` to add all-zero rows for empty stomachs.
  Stomachs with neither a record nor an empty flag are of unknown status
  and left out. Without `stomachs`, nothing changes.
- `ices_lineage` now gives the three unaccepted AphiaIDs of the ICES
  data the lineage of their accepted record (231869 -\> *Aphrodita
  aculeata*, 400596 -\> *Trisopterus esmarkii*, 298205 -\> *Lumpenus
  lampretaeformis*), so Norway pout and the others are one node each and
  `dv_lineage_check(ices_lineage)` is clean. The keys are unchanged. The
  uncorrected table is the new dataset `ices_lineage_raw`, used to
  demonstrate
  [`dv_lineage_check()`](https://sosthenea.github.io/DietView/reference/dv_lineage_check.md).
- The dashboard of
  [`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)
  is drawn on demand: plotly.js is included once, the data of every
  sunburst is stored once as JSON, and a predator’s sunbursts are drawn
  the first time its tab is opened. On the full ICES data (22 predators,
  strata region/year/quarter) the file went from 17.1 MB to 4.1 MB with
  three bands (13.3 MB to 4.0 MB with two), and the build from 70 s to
  9 s. The file still works offline and no longer needs rmarkdown or
  pandoc; `self_contained = FALSE` links plotly.js from a `lib` folder.
- Dashboard cards are keyboard-accessible (`role = "button"`, focusable,
  opened with Enter or Space).
- Install from GitHub with `pak::pak("SostheneA/DietView")`; the README
  no longer points to an R-universe repository.
- The documentation site is built by GitHub Actions and served from the
  `gh-pages` branch; the technical reference is also available as a PDF.
- Lineage gaps are shown as `"<ancestor> (no <rank>)"`. When WoRMS gives
  no taxon at a rank for a group (several polychaete families have no
  order, lancelets have no order, Priapulida have no class),
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
  now fills that rank for records identified below it,
  e.g. `"Polychaeta (no order)"`, instead of leaving them under the
  unidentified node. Gap nodes are light gray in the sunbursts, their
  hover text says they are identified material, and the counts per rank
  are stored in `attr(prep, "lineage_gaps")`.
  [`dv_aggregate_threshold()`](https://sosthenea.github.io/DietView/reference/dv_aggregate_threshold.md),
  [`dv_lineage_check()`](https://sosthenea.github.io/DietView/reference/dv_lineage_check.md),
  richness counts and the digestion diagnostic treat gaps as “no taxon
  at this rank”. Use `dv_prepare(gaps = "keep")` for the previous
  behaviour.
- Rank arguments are case-insensitive and accept the column name or the
  display label (`"class"`, `"Class"`, `" CLASS "`) in
  [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md),
  [`dv_summary()`](https://sosthenea.github.io/DietView/reference/dv_summary.md),
  [`dv_prey_accumulation()`](https://sosthenea.github.io/DietView/reference/dv_prey_accumulation.md),
  [`dv_fo_table()`](https://sosthenea.github.io/DietView/reference/dv_fo_table.md),
  [`dv_matrix()`](https://sosthenea.github.io/DietView/reference/dv_matrix.md)
  and
  [`dv_script()`](https://sosthenea.github.io/DietView/reference/dv_script.md).
  [`dv_rank_table()`](https://sosthenea.github.io/DietView/reference/dv_rank_table.md)
  now errors on an unknown rank instead of returning an empty table.

## DietView 0.1.0

- Initial release.
