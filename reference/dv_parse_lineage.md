# Split a lineage string into rank columns

Metabarcoding pipelines (QIIME 2, DADA2, mothur, SILVA, Greengenes,
MIDORI, BOLD, a BLAST against GenBank) report each sequence's taxonomy
as one string, such as
`"k__Animalia; p__Arthropoda; c__Copepoda; g__Calanus; s__finmarchicus"`.
`dv_parse_lineage()` splits that string into one column per rank, so the
data can be prepared with `dv_prepare(taxonomy = "columns")`, keeping
the reference taxonomy the sequences were assigned with (NCBI, SILVA,
BOLD ...), or only the deepest name can be passed on to WoRMS or GBIF.

## Usage

``` r
dv_parse_lineage(
  data,
  col,
  ranks = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
  sep = ";",
  format = c("auto", "prefixed", "positional"),
  name_col = "prey_name",
  placeholders = c("", "na", "nan", "none", "null", "unassigned", "unclassified",
    "uncultured", "unidentified", "unknown", "metagenome", "environmental sample")
)
```

## Arguments

- data:

  A data.frame.

- col:

  Name of the column holding the lineage string.

- ranks:

  Ranks to create, coarse to fine (default the seven flagship ranks).
  For positional strings they must follow the order of the fields.

- sep:

  Field separator (default `";"`).

- format:

  `"auto"` (default), `"prefixed"` or `"positional"`.

- name_col:

  If not `NULL` (default `"prey_name"`), a column with the deepest
  identified name is added (or overwritten), ready for
  `dv_spec(prey_name = )`.

- placeholders:

  Lower-case values treated as "not identified".

## Value

`data` with one column per rank (and `name_col`).

## Details

Two layouts are read:

- **prefixed** - each field starts with a rank code (`k__`, `d__`,
  `p__`, `c__`, `o__`, `f__`, `g__`, `s__`; also `k:`/`p:` and
  `kingdom:`); fields are placed by their code, so missing ranks are
  allowed. `d__` (domain) is ignored unless `"domain"` is a rank;

- **positional** - plain names in rank order
  (`"Animalia;Arthropoda; ..."`); the i-th field goes to the i-th rank
  of `ranks`.

`format = "auto"` uses prefixed when most strings carry rank codes. For
positional strings, give `ranks` in the order of the fields: MIDORI and
NCBI lineages start with a superkingdom, not a kingdom, so use e.g.
`ranks = c("domain", "phylum", "class", "order", "family", "genus", "species")`
and the same `ranks` in
[`dv_spec()`](https://sosthenea.github.io/DietView/reference/dv_spec.md).
Placeholders such as an empty field, `"NA"`, `"unassigned"`,
`"unclassified"`, `"uncultured"`, `"unidentified"`, `"unknown"`,
`"metagenome"` or a species written `"Genus sp."` become `NA`, so the
record is shown as unidentified at that rank. Trailing NCBI tax IDs
(`"Calanus_6836"`) and underscores (`"Calanus_finmarchicus"`) are
cleaned, and a species given as an epithet only (`s__finmarchicus`) is
completed with its genus.

## See also

[`dv_from_wide()`](https://sosthenea.github.io/DietView/reference/dv_from_wide.md)
to reshape a sample-by-taxon table first.

## Examples

``` r
x <- data.frame(asv = c("a1", "a2", "a3"), taxonomy = c(
  paste("k__Animalia; p__Arthropoda; c__Copepoda; o__Calanoida;",
        "f__Calanidae; g__Calanus; s__finmarchicus"),
  "k__Animalia; p__Chordata; c__Actinopteri; o__; f__; g__; s__",
  "Unassigned"))
dv_parse_lineage(x, "taxonomy")
#>   asv
#> 1  a1
#> 2  a2
#> 3  a3
#>                                                                                           taxonomy
#> 1 k__Animalia; p__Arthropoda; c__Copepoda; o__Calanoida; f__Calanidae; g__Calanus; s__finmarchicus
#> 2                                     k__Animalia; p__Chordata; c__Actinopteri; o__; f__; g__; s__
#> 3                                                                                       Unassigned
#>    kingdom     phylum       class     order    family   genus
#> 1 Animalia Arthropoda    Copepoda Calanoida Calanidae Calanus
#> 2 Animalia   Chordata Actinopteri      <NA>      <NA>    <NA>
#> 3     <NA>       <NA>        <NA>      <NA>      <NA>    <NA>
#>                species            prey_name
#> 1 Calanus finmarchicus Calanus finmarchicus
#> 2                 <NA>          Actinopteri
#> 3                 <NA>                 <NA>
# plain names in rank order, as in many BLAST or BOLD outputs
y <- data.frame(lin = paste("Animalia;Arthropoda;Malacostraca;Euphausiacea",
                            "Euphausiidae;Meganyctiphanes",
                            "Meganyctiphanes norvegica", sep = ";"))
dv_parse_lineage(y, "lin")
#>                                                                                                    lin
#> 1 Animalia;Arthropoda;Malacostraca;Euphausiacea;Euphausiidae;Meganyctiphanes;Meganyctiphanes norvegica
#>    kingdom     phylum        class        order       family           genus
#> 1 Animalia Arthropoda Malacostraca Euphausiacea Euphausiidae Meganyctiphanes
#>                     species                 prey_name
#> 1 Meganyctiphanes norvegica Meganyctiphanes norvegica
```
