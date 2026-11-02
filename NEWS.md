# DietView 0.1.0.9000

## Breaking changes

* `dv_sunburst()` now sizes wedges by prey records by default
  (`mode = "occurrence"`); the choices are ordered `"occurrence"`,
  `"weight"`, `"count"`, as in `run_dietview()`.
* `dv_build_html()` draws the record and weight bands by default
  (`bands = c("occurrence", "weight")`); add `"count"` for distinct prey
  items.
* Default colors follow the hierarchy: `dv_build_html()`, `run_dietview()` and
  the script of `dv_script()` use `dv_palette_tree()` built from the pooled tree
  of the whole prepared dataset, and `dv_sunburst(colors = NULL)` uses
  `dv_palette_tree()` of the tree drawn. A taxon keeps one color across panels
  and neighbouring wedges no longer share a color. `dv_palette()` is still
  exported for label-keyed colors.

## Other changes

* The dashboard of `dv_build_html()` is drawn on demand: plotly.js is included
  once, the data of every sunburst is stored once as JSON, and a predator's
  sunbursts are drawn the first time its tab is opened. On the full ICES data
  (22 predators, strata region/year/quarter) the file went from 17.1 MB to
  4.1 MB with three bands (13.3 MB to 4.0 MB with two), and the build from
  70 s to 9 s. The file still works offline and no longer needs rmarkdown or
  pandoc; `self_contained = FALSE` links plotly.js from a `lib` folder.
* Dashboard cards are keyboard-accessible (`role = "button"`, focusable,
  opened with Enter or Space).

* Install from GitHub with `pak::pak("SostheneA/DietView")`; the README no
  longer points to an R-universe repository.
* The documentation site is built by GitHub Actions and served from the
  `gh-pages` branch; the technical reference is also available as a PDF.
* Lineage gaps are shown as `"<ancestor> (no <rank>)"`. When WoRMS gives no
  taxon at a rank for a group (several polychaete families have no order,
  lancelets have no order, Priapulida have no class), `dv_prepare()` now fills
  that rank for records identified below it, e.g. `"Polychaeta (no order)"`,
  instead of leaving them under the unidentified node. Gap nodes are light gray
  in the sunbursts, their hover text says they are identified material, and
  the counts per rank are stored in `attr(prep, "lineage_gaps")`.
  `dv_aggregate_threshold()`, `dv_lineage_check()`, richness counts and the
  digestion diagnostic treat gaps as "no taxon at this rank". Use
  `dv_prepare(gaps = "keep")` for the previous behaviour.
* Rank arguments are case-insensitive and accept the column name or the display
  label (`"class"`, `"Class"`, `" CLASS "`) in `dv_rank_table()`,
  `dv_summary()`, `dv_prey_accumulation()`, `dv_fo_table()`, `dv_matrix()` and
  `dv_script()`. `dv_rank_table()` now errors on an unknown rank instead of
  returning an empty table.

# DietView 0.1.0

* Initial release.
