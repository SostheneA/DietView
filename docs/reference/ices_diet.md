# Stomach contents of North-East Atlantic fishes (ICES, 2020-2024)

A public extract of the ICES Stomach Content Database: 9,639 prey
records from 4,231 stomachs of 22 predator species caught in the North
Sea, the Skagerrak-Kattegat and the Baltic Sea by national trawl and
acoustic surveys, 2020-2024 (mostly 2022-2024). One row per prey record,
in the format DietView expects, with the stomach-level variables
repeated on each row. Use it with the frozen lineage
[ices_lineage](https://sosthenea.github.io/DietView/reference/ices_lineage.md)
(`taxonomy = "table"`).

## Usage

``` r
ices_diet
```

## Format

A data frame with 9,639 rows and 28 columns:

- stomach_id:

  Stomach (one predator individual) identifier.

- prey_aphia_id:

  WoRMS AphiaID of the prey; `NA` for unidentified material and non-food
  items.

- prey_name:

  Prey name as resolved in WoRMS, `"Unidentified material"`, or the
  non-food item.

- item_type:

  `"prey"`, `"unidentified"` or `"non_food"`.

- digestion_stage:

  ICES digestion code (0, 1, 2), `NA` when not recorded.

- digestion_label:

  Readable digestion stage: `"0 pristine"`, `"1 affected"`,
  `"2 skeletal remains"` or `"not recorded"`. The labels are inferred
  from the older ICES format, whose three classes match the shares of
  codes 0, 1 and 2; check them against the ICES vocabulary.

- prey_count:

  Number of prey individuals in the record.

- prey_weight_g:

  Prey weight (g).

- prey_length_cm:

  Prey length (cm).

- haul_id, country, survey:

  Haul, reporting country and survey.

- year, month, quarter:

  Date of the haul.

- lat, lon, ices_rectangle, depth_m:

  Position and depth of the haul.

- region:

  `"North Sea"`, `"Skagerrak-Kattegat"` or `"Baltic Sea"`.

- predator_aphia_id, predator_latin, predator_common:

  Predator AphiaID, scientific and English name.

- n_fish_pooled:

  Number of fish in the stomach sample (1 or 2; `NA` when not reported).

- length_cm, weight_g:

  Predator length (cm) and weight (g).

- stomach_empty, regurgitated:

  ICES flags (1 = yes, 0 = no).

## Source

ICES Stomach Content Database, ICES, Copenhagen
(<https://stomachdata.ices.dk>), as extracted in the R package stomachr
(Lindmark 2026, <https://github.com/maxlindmark/stomachr>), which also
built the WoRMS classification used in
[ices_lineage](https://sosthenea.github.io/DietView/reference/ices_lineage.md).
ICES data are free to use provided the source is acknowledged; see the
ICES data policy.

## Details

The data are kept close to the ICES export, so they show what real
stomach-content data look like:

- prey are identified to very uneven depth (species, family,
  "Crustacea", "Pisces", or nothing at all: 1,553 records are
  unidentified material);

- 67 records are non-food items (sand, stones, plastic, wood), flagged
  by `item_type == "non_food"`;

- about 1,000 records are Nematoda, which in fish stomachs are mostly
  parasites rather than prey;

- the digestion stage is missing for about a third of the records;

- 17 sampled stomachs pool two fish (`n_fish_pooled == 2` in
  [ices_stomachs](https://sosthenea.github.io/DietView/reference/ices_stomachs.md)),
  7 of them with prey records here.

Deciding what to keep is part of any analysis; the article "Case study:
a complete analysis of public ICES stomach data" walks through it.

Two kinds of correction were made when the data were built
(`data-raw/ices_data.R` in the package sources): rows that only mark an
empty stomach in the ICES export (no prey, weight, count or digestion)
were dropped, and two unit errors in the predator variables were fixed
(Belgian lengths reported in mm, Danish individual weights reported in
kg). Prey weights are in grams and prey lengths in cm throughout.

## See also

[ices_stomachs](https://sosthenea.github.io/DietView/reference/ices_stomachs.md)
for every sampled stomach, empty ones included;
[ices_lineage](https://sosthenea.github.io/DietView/reference/ices_lineage.md)
for the taxonomy.

## Examples

``` r
head(ices_diet[, c("stomach_id", "predator_common", "prey_name", "prey_weight_g")])
#>   stomach_id predator_common             prey_name prey_weight_g
#> 1    S167767         Whiting Unidentified material          0.03
#> 2    S167777         Whiting Unidentified material          0.07
#> 3    S167777         Whiting Unidentified material          0.06
#> 4    S167777         Whiting Unidentified material          0.01
#> 5    S167769         Whiting Unidentified material          0.20
#> 6    S167780         Whiting Unidentified material          1.72
table(ices_diet$item_type)
#> 
#>     non_food         prey unidentified 
#>           67         8019         1553 

spec <- dv_spec(predator = "predator_common", predator_latin = "predator_latin",
                stomach = "stomach_id", prey_id = "prey_aphia_id",
                prey_name = "prey_name", weight = "prey_weight_g",
                digestion = "digestion_label", covariates = c("region", "quarter"))
cod <- ices_diet[ices_diet$predator_common == "Atlantic cod" &
                   ices_diet$item_type != "non_food", ]
prep <- dv_prepare(cod, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
dv_rank_table(dv_tree(prep), "Class")
#>           label value_item value_occ     pct_occ  value_w        pct_w
#> 15 Malacostraca         62       999 42.02776609 2286.830 2.234782e+01
#> 18    Teleostei         46       624 26.25157762 7045.949 6.885584e+01
#> 29           NA          1       192  8.07740850  123.520 1.207087e+00
#> 19           NA          1       153  6.43668490  248.537 2.428803e+00
#> 13   Polychaeta         11       144  6.05805637  380.515 3.718545e+00
#> 26           NA          1        73  3.07109802    6.317 6.173226e-02
#> 16           NA          1        68  2.86074884   55.395 5.413422e-01
#> 20  Ophiuroidea          3        50  2.10349180   25.900 2.531052e-01
#> 22     Bivalvia          7        29  1.22002524    7.203 7.039060e-02
#> 24   Gastropoda          2        19  0.79932688   15.820 1.545994e-01
#> 23  Cephalopoda          4        11  0.46276820   18.931 1.850013e-01
#> 21           NA          1         5  0.21034918    3.930 3.840554e-02
#> 25           NA          1         3  0.12620951    6.739 6.585621e-02
#> 12     Gephyrea          1         2  0.08413967    3.630 3.547382e-02
#> 14           NA          1         2  0.08413967    0.293 2.863313e-03
#> 17       Myxini          1         1  0.04206984    0.840 8.208817e-03
#> 27    Trematoda          1         1  0.04206984    0.001 9.772401e-06
#> 28           NA          1         1  0.04206984    2.550 2.491962e-02
```
