# Choosing a DietView workflow: data types, estimands and reporting

## Start with the *observation*, not the plotting function

DietView visualizes a **taxonomic composition inside a sampling unit**.
It cannot, by itself, establish that a detection equals an ingested
amount or that a sample distribution represents a population. Before
applying the functions, specify what each row means, the sampling unit,
the unit of the quantity, how a missing observation was handled, and the
ecological estimand.

This guide is a companion to the full case studies below, which use the
**same sequence**: question, sample frame, raw structure, validation,
taxonomic mapping, explicit unknowns, metrics, figure, matrix/HTML
output and limitations.

## Select an end-to-end case study

| Your data | Full worked example | What you can describe |
|----|----|----|
| Prey in dissected stomachs | [Real ICES stomach survey](https://sosthenea.github.io/DietView/articles/case-study-ices.md) | Records, prey numbers, mass, %FO, emptiness, digestion and hierarchical identification |
| Real DNA detections in scats | [Real Salish Sea harbour seal DNA](https://sosthenea.github.io/DietView/articles/case-study-dna-seals.md) | DNA detection, mean sample RRA, laboratory/seasonal strata and classification resolution |
| Raw ASV/OTU by sample table | [ASV → taxon → RRA](https://sosthenea.github.io/DietView/articles/case-study-asv-pipeline.md) | Reads per sequence, taxon assignments, pooled reads versus mean RRA; fully simulated |
| Pellets, regurgitates, morphological scat remains | [Morphological remains](https://sosthenea.github.io/DietView/articles/case-study-morphological-remains.md) | Recovered prey records, defensibly estimated individuals and sample detection; fully simulated |
| Survey catches/landings composition | [Fishery survey catch](https://sosthenea.github.io/DietView/articles/case-study-survey-catch.md) | Recorded catch mass and presence per haul; fully simulated, **not** predator diet |
| Benthos/plankton/community grabs | [Benthic community](https://sosthenea.github.io/DietView/articles/case-study-benthic-community.md) | Observed taxonomic abundance, measured mass and sample occurrence; fully simulated, **not** predator diet |

For the foundations see [Getting
started](https://sosthenea.github.io/DietView/articles/getting-started.md),
the [data
model](https://sosthenea.github.io/DietView/articles/data-model.md), and
the [full function
tour](https://sosthenea.github.io/DietView/articles/tour.md). For
alternative lineage formats see [Beyond
stomachs](https://sosthenea.github.io/DietView/articles/other-data.md).

## Variables and measures: a crosswalk

| Question | DietView output | Denominator / unit | Important caveat |
|----|----|----|----|
| What share of prey **records** is in this taxon? | `dv_rank_table(dv_tree(prep), rank)$pct_occ` | All included records at that rank | Not classical %FO; multiple records may occur in one sample |
| What proportion of units detect this taxon? | `dv_fo_table(prep, rank, denominator = "nonempty" or "examined")$pct_fo` | Unique units; include empty units only with an inventory | In DNA, detection ≠ feeding probability; in catches it means presence by haul |
| What share of estimated **individuals**? | `dv_tree(prep, currency = "numbers")` then `pct_occ` | Sum of the declared integer `count` | Do not supply fragments, ASV reads or arbitrary scores as individuals |
| What share of measured **mass**? | `pct_w` with `weight_type = "mass"` | Sum of the specified grams or kg | Recovered mass ≠ consumed biomass; survey catches require effort design |
| What share of pooled sequence reads? | `pct_w` with `weight_type = "reads"` | All reads in the prepared records | High-depth libraries dominate |
| What is the mean normalized DNA signal? | `pct_w` with `weight_type = "rra"` | Sample-level proportions normalized to one, then pooled | Same weight per represented read-positive sample, not a biomass estimate; separate failed assays |
| How finely is material identified? | `dv_resolution(prep)` | Record/quantity shares by finest rank | Resolution reflects methods, references and preservation |
| Did a sample yield no prey data? | `dv_prepare(..., stomachs = inventory, empty_col = ...)` | All examined units, with statuses | Differentiate true empty, known zero and failed/unknown samples |

**Terminology.** Some function argument and return-column names still
say `stomach` or `prey` for historical reasons. In a scat, grab or haul
workflow they mean the **declared sampling unit** and **taxonomic
category**. Set `unit_label` to display the correct noun, and label
scientific tables with the actual study unit. Do not rename a survey
catch as a feeding interaction.

## Three rules that prevent misleading percentages

**1. Always state the currency.** A within-rank percentage may be based
on record counts, individual counts, wet weight, pooled reads or
within-sample normalized RRA. All may be visually represented by a
sunburst but do not estimate the same ecological quantity.

**2. Always state the denominator.** The taxonomic tree partitions all
included observations at each rank, including unknown nodes; its shares
add to 100% by rank. %FO is the fraction of *sampling units containing*
a taxon; it generally does **not** add to 100% across taxa. Distinguish
the denominator of examined units from nonempty units; both are valid
for different questions if explicitly reported.

**3. Unidentified does not mean absent.** A material identified only as
a fish remains in the denominator. A DNA read unassigned to species must
not be quietly given the most likely species label. NA ranks and lineage
gaps have different meanings;
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
distinguishes them where possible.

## Minimum information for a publication-quality application

A DietView application should archive the sampling unit and sampling
frame, including evidence distinguishing true zeros, excluded samples
and failed assays; exact input and exclusion rules, taxonomic
identifiers and authority/version, quantity units, zero/unknown
handling, declared currency and %FO denominator, sample size by group,
package version, R session information and reproducible code. For DNA
work add library preparation, marker, primers, pipeline, controls, read
filtering, batch and detection thresholds. For morphological remains add
the basis for counts, preservation and digestion bias. For grabs and
catches add area/effort, gear/catchability and survey design.

Present uncertainty appropriate to the **independent sampling unit**: a
stomach, predator, scat, haul or grab may be correlated within sampling
clusters. A sunburst is a **descriptive** visualization and does not
provide confidence intervals, hypothesis tests, causal inference or a
study design.

## A small self-contained selection example

``` r

library(DietView)
workflow <- data.frame(
  example = c("ICES stomach", "DNA ASV", "Pellet", "Catch haul", "Benthic grab"),
  unit = c("stomach", "sample", "pellet", "haul", "grab"),
  quantity = c("mass + individuals", "reads/RRA", "individuals",
               "catch mass", "individuals + wet mass"),
  taxonomy = c("frozen WoRMS", "pipeline lineage", "validated columns",
               "frozen table", "validated columns")
)
workflow
#>        example    unit               quantity          taxonomy
#> 1 ICES stomach stomach     mass + individuals      frozen WoRMS
#> 2      DNA ASV  sample              reads/RRA  pipeline lineage
#> 3       Pellet  pellet            individuals validated columns
#> 4   Catch haul    haul             catch mass      frozen table
#> 5 Benthic grab    grab individuals + wet mass validated columns
```

Use
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md)
to state those mappings in code, then
[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md)
to check them. If the data have no defensible taxonomic assignments
(e.g., an isotope mixing-model posterior over broad sources), the
DietView hierarchy is not an appropriate substitute for the original
model and its uncertainty.

**Further reading:** Deagle et al. (2019), *Molecular Ecology*
28:391–406; Thomas et al. (2022), *Scientific Data* 9:68; ICES Stomach
Content Database.
