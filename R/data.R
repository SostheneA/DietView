#' Stomach contents of North-East Atlantic fishes (ICES, 2020-2024)
#'
#' A public extract of the ICES Stomach Content Database: 9,639 prey records
#' from 4,231 stomachs of 22 predator species caught in the North Sea, the
#' Skagerrak-Kattegat and the Baltic Sea by national trawl and acoustic surveys,
#' 2020-2024 (mostly 2022-2024). One row per prey record, in the format
#' DietView expects, with the stomach-level variables repeated on each row.
#' Use it with the frozen lineage [ices_lineage] (`taxonomy = "table"`).
#'
#' The data are kept close to the ICES export, so they show what real
#' stomach-content data look like:
#' * prey are identified to very uneven depth (species, family, "Crustacea",
#'   "Pisces", or nothing at all: 1,553 records are unidentified material);
#' * 67 records are non-food items (sand, stones, plastic, wood), flagged by
#'   `item_type == "non_food"`;
#' * about 1,000 records are Nematoda, which in fish stomachs are mostly
#'   parasites rather than prey;
#' * the digestion stage is missing for about a third of the records;
#' * 17 sampled stomachs pool two fish (`n_fish_pooled == 2` in [ices_stomachs]),
#'   7 of them with prey records here.
#'
#' Deciding what to keep is part of any analysis; the article "Case study: a
#' complete analysis of public ICES stomach data" walks through it.
#'
#' Two kinds of correction were made when the data were built
#' (`data-raw/ices_data.R` in the package sources): rows that only mark an
#' empty stomach in the ICES export (no prey, weight, count or digestion) were
#' dropped, and two unit errors in the predator variables were fixed (Belgian
#' lengths reported in mm, Danish individual weights reported in kg). Prey
#' weights are in grams and prey lengths in cm throughout.
#'
#' @format A data frame with 9,639 rows and 28 columns:
#' \describe{
#'   \item{stomach_id}{Stomach (one predator individual) identifier.}
#'   \item{prey_aphia_id}{WoRMS AphiaID of the prey; `NA` for unidentified
#'     material and non-food items.}
#'   \item{prey_name}{Prey name as resolved in WoRMS, `"Unidentified material"`,
#'     or the non-food item.}
#'   \item{item_type}{`"prey"`, `"unidentified"` or `"non_food"`.}
#'   \item{digestion_stage}{ICES digestion code (0, 1, 2), `NA` when not recorded.}
#'   \item{digestion_label}{Readable digestion stage: `"0 pristine"`,
#'     `"1 affected"`, `"2 skeletal remains"` or `"not recorded"`. The labels
#'     are inferred from the older ICES format, whose three classes match the
#'     shares of codes 0, 1 and 2; check them against the ICES vocabulary.}
#'   \item{prey_count}{Number of prey individuals in the record.}
#'   \item{prey_weight_g}{Prey weight (g).}
#'   \item{prey_length_cm}{Prey length (cm).}
#'   \item{haul_id, country, survey}{Haul, reporting country and survey.}
#'   \item{year, month, quarter}{Date of the haul.}
#'   \item{lat, lon, ices_rectangle, depth_m}{Position and depth of the haul.}
#'   \item{region}{`"North Sea"`, `"Skagerrak-Kattegat"` or `"Baltic Sea"`.}
#'   \item{predator_aphia_id, predator_latin, predator_common}{Predator
#'     AphiaID, scientific and English name.}
#'   \item{n_fish_pooled}{Number of fish in the stomach sample (1 or 2; `NA`
#'     when not reported).}
#'   \item{length_cm, weight_g}{Predator length (cm) and weight (g).}
#'   \item{stomach_empty, regurgitated}{ICES flags (1 = yes, 0 = no).}
#' }
#' @source ICES Stomach Content Database, ICES, Copenhagen
#'   (<https://stomachdata.ices.dk>), as extracted in the R package stomachr
#'   (Lindmark 2026, <https://github.com/maxlindmark/stomachr>), which also
#'   built the WoRMS classification used in [ices_lineage]. ICES data are
#'   free to use provided the source is acknowledged; see the ICES data policy.
#' @seealso [ices_stomachs] for every sampled stomach, empty ones included;
#'   [ices_lineage] for the taxonomy.
#' @examples
#' head(ices_diet[, c("stomach_id", "predator_common", "prey_name", "prey_weight_g")])
#' table(ices_diet$item_type)
#'
#' spec <- dv_spec(predator = "predator_common", predator_latin = "predator_latin",
#'                 stomach = "stomach_id", prey_id = "prey_aphia_id",
#'                 prey_name = "prey_name", weight = "prey_weight_g",
#'                 digestion = "digestion_label", covariates = c("region", "quarter"))
#' cod <- ices_diet[ices_diet$predator_common == "Atlantic cod" &
#'                    ices_diet$item_type != "non_food", ]
#' prep <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
#'                    verbose = FALSE)
#' dv_rank_table(dv_tree(prep), "Class")
"ices_diet"

#' Sampled stomachs of the ICES example data, empty ones included
#'
#' One row per stomach sampled in the hauls of [ices_diet]: 8,886 stomachs of
#' 23 predator species, of which 1,197 are flagged empty. Stomachs without any
#' prey record do not appear in [ices_diet], so this table is the one to use for
#' the proportion of empty stomachs or the number of fish sampled per stratum.
#'
#' @format A data frame with 8,886 rows and 20 columns: `stomach_id`,
#'   `haul_id`, `country`, `survey`, `year`, `month`, `quarter`, `lat`, `lon`,
#'   `ices_rectangle`, `depth_m`, `region`, `predator_aphia_id`,
#'   `predator_latin`, `predator_common`, `n_fish_pooled`, `length_cm`,
#'   `weight_g`, `stomach_empty`, `regurgitated` (as in [ices_diet]).
#' @source As [ices_diet].
#' @examples
#' # share of stomachs flagged empty, by predator
#' e <- tapply(ices_stomachs$stomach_empty %in% 1, ices_stomachs$predator_common, mean)
#' round(100 * sort(e, decreasing = TRUE), 1)[1:5]
"ices_stomachs"

#' Frozen WoRMS lineage for the ICES example data
#'
#' The taxonomic lineage (kingdom to species) of every AphiaID in [ices_diet],
#' as resolved in WoRMS. Pass it to [dv_prepare()] with `taxonomy = "table"`:
#' its key column, `prey_aphia_id`, has the same name as the prey key of
#' [ices_diet]. A taxon that is itself above species (e.g. "Crustacea", a
#' subphylum) has `NA` at the finer ranks, which DietView shows as the
#' unidentified share of that branch. WoRMS gives no order to some polychaetes
#' and lancelets and no class to Priapulida, so a few records identified to
#' family or species also reach an `NA` node at those ranks.
#'
#' @format A data frame with 461 rows and 10 columns: `prey_aphia_id`,
#'   `scientific_name`, `worms_rank` (the WoRMS rank of the name), then the
#'   seven ranks `kingdom`, `phylum`, `class`, `order`, `family`, `genus`,
#'   `species`.
#' @source World Register of Marine Species (WoRMS, <https://www.marinespecies.org>),
#'   as compiled in the R package stomachr (Lindmark 2026); kingdom and species
#'   columns derived from the WoRMS phylum and the name's rank.
#' @examples
#' ices_lineage[ices_lineage$scientific_name %in% c("Crustacea", "Crangon crangon"), ]
"ices_lineage"
