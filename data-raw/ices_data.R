# Build the ICES example datasets shipped with DietView: ices_diet,
# ices_stomachs and ices_lineage (data/*.rda).
#
# Source: the public extract of the ICES Stomach Content Database (new ICES
# stomach format, 2020-2024) distributed with the R package stomachr
# (Lindmark 2026, MIT, https://github.com/maxlindmark/stomachr), and the WoRMS
# classification that stomachr built for those AphiaIDs. Copies of the source
# files are in data-raw/ices/, with the ICES terms of use and the stomachr
# licence. Data acknowledgment: ICES Stomach Content Database, ICES, Copenhagen.
#
# Run from the package root:  Rscript data-raw/ices_data.R

raw <- function(f) read.csv(file.path("data-raw", "ices", f), stringsAsFactors = FALSE,
                            na.strings = c("NA", ""))

files <- raw("File_information.csv")
hauls <- raw("HaulInformation.csv")
preds <- raw("PredatorInformation.csv")
prey  <- raw("PreyInformation.csv")
worms <- raw("worms_lookup_stomachr.csv")

# ---- lineage table: the seven ranks DietView uses ---------------------------
kingdom_of <- function(phylum) {
  ifelse(phylum %in% c("Chlorophyta"), "Plantae",
         ifelse(phylum %in% c("Ochrophyta"), "Chromista", "Animalia"))
}
species_of <- function(name, rank) {
  sp <- ifelse(rank %in% c("Species", "Subspecies"), name, NA_character_)
  # a subspecies is reported under its species
  vapply(strsplit(sp, " "), function(x) if (all(is.na(x))) NA_character_
         else paste(x[1:2], collapse = " "), character(1))
}
lineage <- data.frame(
  prey_aphia_id   = worms$aphia_id,   # same name as the key column of ices_prey.csv
  scientific_name = worms$scientific_name,
  worms_rank      = worms$rank,
  kingdom = kingdom_of(worms$phylum),
  phylum  = worms$phylum,
  class   = worms$class,
  order   = worms$order,
  family  = worms$family,
  genus   = worms$genus,
  species = species_of(worms$scientific_name, worms$rank),
  stringsAsFactors = FALSE
)
# A name that is itself a rank above species (e.g. "Crustacea", a subphylum)
# keeps only the ranks WoRMS gives it; everything finer stays NA, which is
# exactly what DietView shows as the unidentified share.
lineage <- lineage[!duplicated(lineage$prey_aphia_id), ]

# ---- stomachs (predators) ----------------------------------------------------
common <- c(
  "Gadus morhua" = "Atlantic cod", "Merlangius merlangus" = "Whiting",
  "Pleuronectes platessa" = "European plaice", "Scomber scombrus" = "Atlantic mackerel",
  "Trachurus trachurus" = "Atlantic horse mackerel", "Merluccius merluccius" = "European hake",
  "Chelidonichthys lucerna" = "Tub gurnard", "Amblyraja radiata" = "Thorny skate",
  "Squalus acanthias" = "Spiny dogfish", "Scophthalmus maximus" = "Turbot",
  "Scophthalmus rhombus" = "Brill", "Raja clavata" = "Thornback ray",
  "Lophius piscatorius" = "Angler", "Molva molva" = "Ling",
  "Eutrigla gurnardus" = "Grey gurnard", "Pollachius pollachius" = "Pollack",
  "Leucoraja naevus" = "Cuckoo ray", "Raja montagui" = "Spotted ray",
  "Raja brachyura" = "Blonde ray", "Hippoglossus hippoglossus" = "Atlantic halibut",
  "Alosa fallax" = "Twaite shad", "Mustelus asterias" = "Starry smooth-hound",
  "Mustelus" = "Smooth-hounds")

h <- hauls[match(preds$tblHaulID, hauls$tblHaulID), ]
latin <- worms$scientific_name[match(preds$AphiaIDPredator, worms$aphia_id)]
region <- with(h, ifelse(Survey %in% c("BITS", "BIAS", "G1022", "G2829"), "Baltic Sea",
                  ifelse(HaulLat > 57 & HaulLong > 7.5, "Skagerrak-Kattegat", "North Sea")))

stomachs <- data.frame(
  stomach_id      = paste0("S", preds$tblPredatorInformationID),
  haul_id         = paste0("H", preds$tblHaulID),
  country         = files$Country[match(preds$tblUploadID, files$tblUploadID)],
  survey          = h$Survey,
  year            = preds$Year,
  month           = preds$Month,
  quarter         = (preds$Month - 1) %/% 3 + 1,
  lat             = h$HaulLat,
  lon             = h$HaulLong,
  ices_rectangle  = h$ICESrectangle,
  depth_m         = h$Depth,
  region          = region,
  predator_aphia_id = preds$AphiaIDPredator,
  predator_latin  = latin,
  predator_common = unname(common[latin]),
  n_fish_pooled   = preds$Number,
  length_cm       = preds$Length,
  weight_g        = preds$IndWgt,
  stomach_empty   = preds$StomachEmpty,
  regurgitated    = preds$Regurgitated,
  stringsAsFactors = FALSE
)

# ---- prey records ---------------------------------------------------------------
# A prey row with no AphiaID, weight, count or digestion stage is how the ICES
# export gives an EMPTY stomach a row; it is not an unidentified prey (same rule
# as stomachr::join_stomach_data()). Those rows are dropped.
placeholder <- is.na(prey$AphiaIDPrey) & is.na(prey$Weight) & is.na(prey$Count) &
  is.na(prey$DigestionStage) & is.na(prey$OtherItems)
prey <- prey[!placeholder, ]

country <- files$Country[match(prey$tblUploadID, files$tblUploadID)]
unit_w  <- ifelse(is.na(prey$UnitWgt), ifelse(country == "NO", "mg", "g"), prey$UnitWgt)
unit_l  <- ifelse(is.na(prey$UnitLngt), ifelse(country == "NO", "cm", "mm"), prey$UnitLngt)

other <- tolower(trimws(prey$OtherItems))
non_food <- !is.na(other) & grepl("sand|stone|plastic|wood", other) &
  !grepl("organic", other)
item_type <- ifelse(!is.na(prey$AphiaIDPrey), "prey",
                    ifelse(non_food, "non_food", "unidentified"))
prey_name <- worms$scientific_name[match(prey$AphiaIDPrey, worms$aphia_id)]
prey_name[item_type == "unidentified"] <- "Unidentified material"
prey_name[item_type == "non_food"] <- prey$OtherItems[item_type == "non_food"]

prey_tab <- data.frame(
  stomach_id     = paste0("S", prey$tblPredatorInformationID),
  prey_aphia_id  = prey$AphiaIDPrey,
  prey_name      = prey_name,
  item_type      = item_type,
  digestion_stage = prey$DigestionStage,
  # ICES codes 0/1/2. Labels inferred from the older ICES format ("Pristine",
  # "Affected by digestion", "Skeletal remains"), whose shares match codes
  # 0/1/2 closely: check them against the ICES vocabulary before teaching.
  digestion_label = ifelse(is.na(prey$DigestionStage), "not recorded",
    c("0" = "0 pristine", "1" = "1 affected", "2" = "2 skeletal remains")[
      as.character(prey$DigestionStage)]),
  prey_count     = prey$Count,
  prey_weight_g  = ifelse(unit_w == "mg", prey$Weight / 1000, prey$Weight),
  prey_length_cm = ifelse(unit_l == "mm", prey$Length / 10, prey$Length),
  stringsAsFactors = FALSE
)
# carry the stomach-level variables onto each prey record (long table)
prey_tab <- cbind(prey_tab,
                  stomachs[match(prey_tab$stomach_id, stomachs$stomach_id),
                           setdiff(names(stomachs), "stomach_id")])

# ---- documented corrections ----------------------------------------------------
# 1. Placeholder rows: in the ICES export a stomach flagged empty can carry one
#    bare prey row (no weight, count or digestion stage). It is a marker of the
#    empty stomach, not an unidentified prey, so it is dropped.
empty_ids <- stomachs$stomach_id[stomachs$stomach_empty %in% 1]
marker <- prey_tab$stomach_id %in% empty_ids & is.na(prey_tab$prey_weight_g) &
  is.na(prey_tab$prey_count) & is.na(prey_tab$digestion_stage)
prey_tab <- prey_tab[!marker, ]
# 2. Unit errors in the predator variables: Belgian lengths were reported in mm
#    and Danish individual weights in kg (a Fulton condition factor of ~0.001
#    instead of ~1 exposes it). They are converted to cm and g.
fix_units <- function(x) {
  x$length_cm[x$country %in% "BE"] <- x$length_cm[x$country %in% "BE"] / 10
  x$weight_g[x$country %in% "DK"]  <- x$weight_g[x$country %in% "DK"] * 1000
  x
}
stomachs <- fix_units(stomachs)
prey_tab <- fix_units(prey_tab)

ices_diet     <- prey_tab
ices_stomachs <- stomachs
ices_lineage  <- lineage
rownames(ices_diet) <- rownames(ices_stomachs) <- rownames(ices_lineage) <- NULL

dir.create("data", showWarnings = FALSE)
save(ices_diet, file = "data/ices_diet.rda", compress = "xz")
save(ices_stomachs, file = "data/ices_stomachs.rda", compress = "xz")
save(ices_lineage, file = "data/ices_lineage.rda", compress = "xz")

message(sprintf("dropped %d empty-stomach marker rows", sum(placeholder) + sum(marker)))
message(sprintf("ices_diet: %d records (%d prey, %d unidentified, %d non-food) in %d stomachs of %d predators",
                nrow(ices_diet), sum(ices_diet$item_type == "prey"),
                sum(ices_diet$item_type == "unidentified"), sum(ices_diet$item_type == "non_food"),
                length(unique(ices_diet$stomach_id)), length(unique(ices_diet$predator_latin))))
message(sprintf("ices_stomachs: %d stomachs (%d flagged empty)", nrow(ices_stomachs),
                sum(ices_stomachs$stomach_empty %in% 1)))
message(sprintf("ices_lineage: %d taxa", nrow(ices_lineage)))
