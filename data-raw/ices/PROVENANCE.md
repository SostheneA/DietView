# Provenance of the ICES example data

This directory contains the four ICES Stomach Content Data CSV files as
redistributed by Max Lindmark in `stomachr` (`inst/extdata/`). They are
**byte-for-byte identical** to the source files at the Git versions checked
on 2026-11-16.

- Original provider: ICES, Copenhagen — https://stomachdata.ices.dk/inventory
- Intermediate distribution: https://github.com/maxlindmark/stomachr
- Acquisition script in stomachr: `data-raw/build_example_data.R`
- Acquisition parameters: `year = 2020:2024`, `ecoregion = "Greater North Sea"`
- Public data licence according to the ICES inventory: CC BY 4.0
  https://creativecommons.org/licenses/by/4.0/

| File | Source Git blob SHA-1 |
|---|---|
| File_information.csv | `02835ba0aaa409202e8e0fbf570d5388e499a121` |
| HaulInformation.csv | `14e55e2dd9f2221b028e530b34cb9ee57da9cd3f` |
| PredatorInformation.csv | `bdbc37fa96e829b39aa5550f3a1a5e6240538995` |
| PreyInformation.csv | `59aecc28ebc54df71e245cc3b3845750447ab393` |

## Scope

30 source uploads, 904 hauls, 8,886 predator/stomach rows and 10,210 original
prey rows. The reproducible DietView preparation script (`data-raw/ices_data.R`)
drops 192 fully empty prey rows and another 379 empty-stomach markers, leaving
9,639 prey observations (94.41% of the original extract). All 8,886 stomach
rows are retained. This ratio is relative to the supplied *extract*, not the
entire ICES Stomach Content Database.

The final prey records cover 2020 (17), 2021 (13), 2022 (4,297), 2023
(2,163) and 2024 (3,149); reporting countries are DK (4,072), SE (3,086),
NL (1,091), DE (911), BE (396) and NO (83).

## Transformations

DietView joins source tables; retains unidentified prey and non-food items;
removes only placeholder records; converts prey weights and lengths to grams
and centimetres; corrects the flagged BE length and DK predator-weight units;
constructs display names and covariates; and adds a frozen WoRMS lineage.
The source and changed lineage tables are both kept.

**Important:** `region` is derived from an internal survey/coordinate heuristic
and is not a directly downloaded ICES ecoregion label. Digestion-code wordings
were inferred from the older ICES format and need confirmation against the
current ICES vocabulary before use as definitive standardised labels.

## Licence scope

`stomachr` and DietView code use the MIT licence. The public ICES observations
are licensed CC BY 4.0; any additional restricted ICES data may have different
terms. The source CSV files do not contain row-level licence flags, so this
provenance document does not certify each cruise individually. Current ICES
policy and original source permissions should be checked for other extracts.
