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
#' and lancelets and no class to Priapulida, so a few prey identified to family
#' or species have `NA` at those ranks. [dv_prepare()] shows those as gray
#' lineage gaps such as `"Polychaeta (no order)"`, not as unidentified
#' material; `gaps = "keep"` leaves them `NA`.
#'
#' @format A data frame with 461 rows and 10 columns: `prey_aphia_id`,
#'   `scientific_name`, `worms_rank` (the WoRMS rank of the name), then the
#'   seven ranks `kingdom`, `phylum`, `class`, `order`, `family`, `genus`,
#'   `species`.
#' @source World Register of Marine Species (WoRMS, <https://www.marinespecies.org>),
#'   as compiled in the R package stomachr (Lindmark 2026); kingdom and species
#'   columns derived from the WoRMS phylum and the name's rank.
#' Three AphiaIDs reported in the ICES data are unaccepted in WoRMS (231869
#' *Aphrodite aculeata*, 400596 *Trisopterus esmarki*, 298205 *Lumpenus
#' lampetraeformis*). They keep their key here but carry the lineage of their
#' accepted record (129840, 126444 and 154675), so each species is one node of
#' the tree. The table as built from the reported AphiaIDs is
#' [ices_lineage_raw].
#'
#' @examples
#' ices_lineage[ices_lineage$scientific_name %in% c("Crustacea", "Crangon crangon"), ]
#' nrow(dv_lineage_check(ices_lineage))   # no spelling variants
"ices_lineage"

#' Uncorrected WoRMS lineage for the ICES example data
#'
#' The lineage of [ices_diet] as built from the AphiaIDs as reported, before
#' unaccepted AphiaIDs were given the lineage of their accepted record. It
#' keeps three species under two spellings each (*Aphrodita*/*Aphrodite
#' aculeata*, *Trisopterus esmarkii*/*esmarki*, *Lumpenus
#' lampretaeformis*/*lampetraeformis*), which split one taxon into two nodes.
#' It is shipped to demonstrate [dv_lineage_check()]; use [ices_lineage] for
#' analyses.
#'
#' @format A data frame with the same 461 rows and 10 columns as
#'   [ices_lineage].
#' @source As [ices_lineage].
#' @examples
#' dv_lineage_check(ices_lineage_raw)[, c("check", "rank", "label", "variant")]
"ices_lineage_raw"

#' DNA metabarcoding diet of Salish Sea harbour seals
#'
#' Prey composition of 4,625 harbour seal (*Phoca vitulina*) scats collected at
#' 52 haul-out sites of the Salish Sea (British Columbia and Washington State)
#' from 2012 to 2018, identified by DNA metabarcoding (16S, plus COI for
#' salmonids and some fishes). One row per prey taxon in a scat. It is the
#' public dataset of Thomas et al. (2022), shipped to show DietView on
#' non-stomach, read-based diet data; see the article "Beyond stomachs".
#'
#' `diet_fraction` is the authors' proportion of the scat's prey DNA assigned
#' to that prey (relative read abundance, combining both markers); it sums to
#' 1 within each scat. Use it as the weight with `weight_type = "rra"`. Some
#' sequences could not be split between closely related species and are
#' reported as alternatives (`"Sebastes flavidus OR Sebastes melanops"`):
#' [salish_seal_lineage] places them at the finest rank the candidates share,
#' so they show as unidentified below that rank, as a digested stomach item
#' would.
#'
#' @format A data frame with 11,641 rows and 14 columns:
#' \describe{
#'   \item{sample_id}{Scat identifier (unique).}
#'   \item{predator}{"Harbour seal".}
#'   \item{site, lat, lon}{Haul-out site and its position (decimal degrees).}
#'   \item{year, month}{Collection date.}
#'   \item{season}{Factor derived from `month` (winter = Dec-Feb, ...).}
#'   \item{lab}{Laboratory that processed the scat (DFO, UBC or WDFW).}
#'   \item{prey_label}{Prey taxon as assigned, or alternatives joined by "OR".}
#'   \item{common_name}{Prey common name, as given by the authors.}
#'   \item{reads_16S, reads_COI}{Sequence reads of the prey for each marker.}
#'   \item{diet_fraction}{Proportion of the scat's prey DNA (0-1).}
#' }
#' @source Thomas, A. C., Deagle, B., Nordstrom, C., Majewski, S., Nelson,
#'   B. W., Acevedo-Gutiérrez, A., Jeffries, S., Moore, J., Louden, A., Allegue,
#'   H., Pearson, S., Schmidt, M., & Trites, A. W. (2022). Data on the diets of
#'   Salish Sea harbour seals from DNA metabarcoding. *Scientific Data*, 9, 68.
#'   \doi{10.1038/s41597-022-01152-5}. Data: \doi{10.6084/m9.figshare.12043173},
#'   released under CC0 1.0. Labels were cleaned (underscores to spaces);
#'   nothing else was changed.
#' @examples
#' spec <- dv_spec(predator = "predator", stomach = "sample_id",
#'                 prey_name = "prey_label", weight = "diet_fraction",
#'                 weight_type = "rra", covariates = c("season", "year", "site"),
#'                 unit_label = "scat")
#' prep <- dv_prepare(salish_seal_dna, spec, taxonomy = "table",
#'                    lineage = salish_seal_lineage, verbose = FALSE)
#' dv_rank_table(dv_tree(prep), "Family")[1:5, ]
"salish_seal_dna"

#' Frozen WoRMS lineage for the Salish Sea harbour seal data
#'
#' The lineage (kingdom to species) of every `prey_label` of
#' [salish_seal_dna], resolved against WoRMS with [dv_taxonomy_worms()] when
#' the data were built (one misspelling, *Chirolophus decoratus*, was matched to
#' *Chirolophis decoratus*). For a label listing alternatives ("A OR B"), the
#' ranks the candidate species share are kept and the finer ranks are `NA`.
#' Pass it to [dv_prepare()] with `taxonomy = "table"`.
#'
#' @format A data frame with 117 rows and 10 columns: `prey_label`, the seven
#'   ranks `kingdom` to `species`, `n_candidates` (species listed in the label)
#'   and `aphia_id` (the WoRMS AphiaID, for single-species labels).
#' @source World Register of Marine Species (WoRMS,
#'   <https://www.marinespecies.org>), retrieved 2026-11-04; see
#'   `data-raw/salish_seal.R`.
#' @examples
#' salish_seal_lineage[salish_seal_lineage$n_candidates > 1,
#'                     c("prey_label", "family", "genus")]
"salish_seal_lineage"
