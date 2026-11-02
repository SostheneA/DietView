# DietView 0.1.0.9000

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
