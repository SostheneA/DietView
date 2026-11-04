# DietView 0.1.0

* Initial CRAN release.

## Beyond stomach contents

* `dv_prepare(taxonomy = "gbif")` and the new `dv_taxonomy_gbif()` resolve prey
  against the GBIF Backbone Taxonomy (all kingdoms), for terrestrial and
  freshwater diets. Same rules as WoRMS: key, exact name, then fuzzy name, a
  per-prey provenance log, an on-disk cache and `dv_taxonomy_report()`. GBIF
  adds two review flags: `"higherrank"` matches and `low_confidence`. No new
  dependency.
* `dv_parse_lineage()` splits lineage strings from metabarcoding pipelines
  (QIIME 2, DADA2, SILVA, MIDORI, BOLD, BLAST) into rank columns, so the
  reference taxonomy used for assignment (NCBI, SILVA, BOLD...) can be kept
  with `taxonomy = "columns"`.
* `dv_from_wide()` reshapes wide sample-by-taxon tables (ASV/OTU tables, catch
  compositions) into the long format and joins sample metadata.
* `dv_spec(weight_type = )`: `"mass"` (default), `"reads"` (pooled read share)
  or `"rra"` (relative read abundance, the mean over samples of per-sample read
  proportions). Labels of the weight views follow.
* `dv_resolution()`: the finest rank each record reaches, by any grouping,
  without needing a digestion column (the identification-resolution
  diagnostic for DNA data); `dv_digestion_diagnostic()` now builds on it, and
  the Shiny app shows a "Resolution" tab when there is no digestion column.
* `dv_spec(unit_label = )`: names the sampling unit ("scat", "sample",
  "haul"...) in messages, printouts, the dashboard and the Shiny app.
  Argument and column names are unchanged.
* New example data: `salish_seal_dna` and `salish_seal_lineage`, the DNA
  metabarcoding diet of 4,625 Salish Sea harbour seal scats (Thomas et al.
  2022, CC0).
* `dv_cache_clear()` gains `source = c("all", "worms", "gbif")`.
* New article: "Beyond stomachs: DNA metabarcoding, scats and other
  compositional data".
