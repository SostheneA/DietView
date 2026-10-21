# DietView example data: data dictionary

The two example files are **invented** for documentation and testing. They have
the structure of the southern Gulf of St. Lawrence diet data but none of its
values: 24 prey records from 11 stomachs of three predators. Use them to learn
the functions, not to learn about these fish.

One row is **one prey taxon found in one stomach**. Column names are free; you
map them to DietView roles once with `dv_spec()`.

| Column | Role in `dv_spec()` | Required | Type | Meaning in the example |
|---|---|---|---|---|
| `predator_species_common_name` | `predator` | yes | chr | Predator species. |
| `predator_species_latin_name` | `predator_latin` | no | chr | Used for identification photos. |
| `stomach_id` | `stomach` | yes | chr | Stomach identifier. **Must be unique across the whole table**, not only within a predator. |
| `aphia_id` | `prey_id` | one of id/name | int | WoRMS AphiaID of the prey; empty when none applies. |
| `verified_name` | `prey_name` | one of id/name | chr | Scientific name at the rank reached by identification. |
| `prey_weight` | `weight` | no | num | Wet weight of that prey in that stomach, in grams. |
| `number_of_prey` | `count` | no | int | Number of individuals; empty when they cannot be counted (e.g. unidentified material). |
| `digestion_level_id` | `digestion` | no | int | 1 = fresh, 2 = slightly digested, 3 = partly digested, 4 = well digested, 5 = unrecognizable. |
| `period`, `year`, `size_class`, `size_bin`, `region` | covariates | no | chr/int | Strata. Size bins are per predator. |
| `somatic_length_cm` | none | no | num | Predator total length (cm), source of the size strata. |

## Rules

- **An empty rank is a record of where identification stopped, not an error.**
  Leave it empty. DietView shows those records as an unidentified category
  below the last rank reached, so every ring still accounts for all the
  material. The example contains prey identified only to class (`Bivalvia`,
  `Copepoda`), to order or family (`Amphipoda`, `Decapoda`, `Mysida`,
  `Gammaridae`), and material that could not be placed at all.
- **One lineage per prey key.** A given AphiaID or name must carry the same
  lineage in every row.
- **Covariates are opt-in.** Declare only those you want to stratify by.

## The lineage table

`dietview_example_lineage.csv` holds one row per prey name (`verified_name`)
with the columns `kingdom`, `phylum`, `class`, `order`, `family`, `genus` and
`species`. Join it with `dv_prepare(taxonomy = "table", lineage = ...)` for a
fully offline run. Empty (or `NA`) cells mark where identification stopped. Each name
must appear once; a name in the diet table that is absent from the lineage
table is reported and treated as fully unidentified.

## Minimal `dv_spec()` for this file

```r
spec <- dv_spec(
  predator       = "predator_species_common_name",
  predator_latin = "predator_species_latin_name",
  stomach        = "stomach_id",
  prey_id        = "aphia_id",
  prey_name      = "verified_name",
  weight         = "prey_weight",
  count          = NULL,                 # each record counts once (prey records)
  digestion      = "digestion_level_id",
  covariates     = c("period", "size_class", "size_bin", "region")
)
```
