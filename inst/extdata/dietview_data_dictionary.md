# DietView input format — data dictionary

One row = **one prey record in one stomach**. Column names are free; you map them
to DietView roles once via `dv_spec()`. The example file
(`dietview_example.csv`) uses the names below.

| Column | Role in `dv_spec()` | Required | Type | Notes |
|---|---|---|---|---|
| `predator_species_common_name` | `predator` | yes | chr | One predator per row. |
| `predator_species_latin_name` | `predator_latin` | no | chr | Used to auto-fetch an ID photo. |
| `stomach_id` | `stomach` | yes | chr | Unit of occurrence; used for stomach counts. |
| `aphia_id` | `prey_id` | one of id/name | int | WoRMS AphiaID of the prey (preferred key). |
| `verified_name` | `prey_name` | one of id/name | chr | Prey name; fallback key if no AphiaID. |
| `prey_weight` | `weight` | no* | num | Weight currency (declare its meaning: wet, reconstructed, …). Empty → 0. |
| `number_of_prey` | `count` | no | int | Optional. If used as `count`, occurrence = summed individuals (%N); otherwise occurrence = one appearance per row. |
| `digestion_level_id` | `digestion` | no | int/chr | Enables the digestion-bias diagnostic. |
| `period` | covariate | no | chr | Any stratifier. |
| `year` | covariate | no | int | Can derive `period` via `dv_add_period()`. |
| `somatic_length_cm` | (source) | no | num | Predator length; source for size class / bins. |
| `size_class` | covariate | no | chr | e.g. juvenile / adult. |
| `size_bin` | covariate | no | chr | e.g. `[40-50[`; build with `dv_size_bins()`. |
| `region` | covariate | no | chr | Any spatial stratum. |
| `kingdom`,`phylum`,`class`,`order`,`family`,`genus`,`species` | `ranks` | see note | chr | Prey lineage. Present → use `taxonomy = "columns"`. Absent → `taxonomy = "worms"` fills them from `aphia_id`/`verified_name`. |

\* No weight column just means weight-based views (%W) are empty; occurrence
views still work.

## Rules

- **Taxonomic NAs are information, not errors.** Where identification stops (or
  WoRMS has no finer rank), leave the deeper rank columns as `NA`. DietView keeps
  them as an explicit "NA" category so the percentages still sum to 100% and the
  identification gaps stay visible. The example has three deliberate cases:
  class-only prey (`Bivalvia`, `Copepoda`, `Teleostei`), family/order-only prey
  (`Gammaridae`, `Amphipoda`, `Decapoda`, `Mysida`), and fully unidentified
  material (all ranks `NA`).
- **One consistent lineage per prey.** A given `verified_name`/`aphia_id` should
  carry the same lineage in every row.
- **Covariates are opt-in.** Declare only the ones you want to stratify by; add
  or drop columns freely — nothing is hard-coded.

## Minimal `dv_spec()` for this file

```r
spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",
  prey_name      = "verified_name",
  weight         = "prey_weight",
  count          = NULL,                 # occurrence = one appearance per record
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)
```
