# DietView (development version)

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
* `dv_cache_clear()` gains `source = c("all", "worms", "gbif")`.
* New article: "Beyond stomachs: DNA metabarcoding, scats and other
  compositional data".

# DietView 0.1.0

* Initial CRAN release.
