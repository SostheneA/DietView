## Builds inst/extdata/dietview_sim.csv and inst/extdata/dietview_sim_lineage.csv:
## an invented survey whose true diet is known, used by the vignette "A known diet".
## Identification is lost with digestion, faster for some prey classes than others.
set.seed(20261020)
ranks <- c("kingdom", "phylum", "class", "order", "family", "genus", "species")
lin <- read.csv("inst/extdata/dietview_example_lineage.csv", na.strings = c("NA", ""))
sp  <- lin[!is.na(lin$species), c("verified_name", ranks)]
rownames(sp) <- sp$verified_name

# true diets: probability that a prey record belongs to each species
diet <- list(
  "Atlantic cod" = c("Pandalus borealis" = .30, "Chionoecetes opilio" = .15,
                     "Ammodytes dubius" = .20, "Osmerus mordax" = .15,
                     "Themisto libellula" = .15, "Calanus finmarchicus" = .05),
  "Alewife"      = c("Calanus finmarchicus" = .55, "Themisto libellula" = .30,
                     "Pandalus borealis" = .05, "Ammodytes dubius" = .10))
latin  <- c("Atlantic cod" = "Gadus morhua", "Alewife" = "Alosa pseudoharengus")
len_mu <- c("Atlantic cod" = 45, "Alewife" = 22)
len_sd <- c("Atlantic cod" = 12, "Alewife" = 4)
# typical wet mass (g) of one prey record (illustrative values)
mass <- c("Pandalus borealis" = 3, "Chionoecetes opilio" = 8, "Ammodytes dubius" = 4,
          "Osmerus mordax" = 10, "Themisto libellula" = 0.1, "Calanus finmarchicus" = 0.002)
# how fast identification is lost, by prey class (higher = faster)
fragility <- c(Teleostei = -0.5, Actinopteri = -0.5, Malacostraca = 0.3, Copepoda = 1.0)

rows <- list(); k <- 0L
for (p in names(diet)) {
  for (s in seq_len(150)) {
    year   <- sample(c(2004:2006, 2018:2019), 1)
    region <- sample(c("Northumberland Strait", "Magdalen Shallows"), 1)
    L      <- max(8, round(rnorm(1, len_mu[[p]], len_sd[[p]])))
    pr     <- diet[[p]]
    n_it   <- min(1 + rpois(1, 1.2), length(pr))
    for (q in sample(names(pr), n_it, prob = pr)) {          # distinct taxa per stomach
      g    <- sample(1:5, 1, prob = c(.15, .30, .25, .20, .10))  # digestion score
      fr   <- fragility[sp[q, "class"]]; fr <- if (is.na(fr)) 0 else fr
      lost <- rbinom(1, 6, plogis(-3 + 0.9 * (g - 1) + fr))
      keep <- 7 - lost                                        # ranks still named
      if (g == 5 && runif(1) < 0.3) keep <- 0                 # unplaceable material
      lab  <- unlist(sp[q, ranks]); lab[seq_len(7) > keep] <- NA
      k <- k + 1L
      rows[[k]] <- data.frame(
        predator_species_common_name = p,
        predator_species_latin_name  = latin[[p]],
        stomach_id    = sprintf("%s%03d", toupper(substr(p, 1, 2)), s),
        verified_name = if (keep == 0) "unidentified material" else lab[[max(which(!is.na(lab)))]],
        prey_weight   = round(rlnorm(1, log(mass[[q]]), 0.4) * (1 - 0.18 * (g - 1)), 4),
        digestion_level_id = g,
        year = year,
        period = if (year <= 2006) "2004-2006" else "2018-2019",
        region = region,
        somatic_length_cm = L,
        true_species = q,
        as.list(lab),
        stringsAsFactors = FALSE)
    }
  }
}
sim <- do.call(rbind, rows)
lineage_out <- unique(sim[, c("verified_name", ranks)])
stopifnot(!anyDuplicated(lineage_out$verified_name))           # one lineage per name
write.csv(sim[, setdiff(names(sim), ranks)], "inst/extdata/dietview_sim.csv",
          row.names = FALSE, na = "")
write.csv(lineage_out, "inst/extdata/dietview_sim_lineage.csv", row.names = FALSE, na = "")
