# Silence R CMD check "no visible binding" NOTEs for column names used inside
# dplyr data-masking verbs (dv_build_tree(), dv_digestion_diagnostic()).
utils::globalVariables(c("value_item", "occ", "w", "n_records", "weight"))
