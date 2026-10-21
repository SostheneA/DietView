# Describe the sampled diet dataset

A quick overview of sample structure, computed before any figure: how
many stomachs and prey records each predator contributes, how many
distinct prey taxa were seen, and the mean number of prey records per
stomach. Optionally broken down by a covariate.

## Usage

``` r
dv_summary(prep, by = NULL, rank = NULL)
```

## Arguments

- prep:

  A `dietview_prep` from
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- by:

  Optional covariate column to break the summary down by.

- rank:

  Optional rank (one of `prep$ranks`, e.g. `"family"`) at which `n_taxa`
  is counted. `NULL` (default) uses the finest resolved label.

## Value

A data.frame with one row per predator (and per `by` level), with
`n_stomachs`, `n_records`, `n_taxa`, `records_per_stomach`, and, when a
weight column is declared, `total_weight`.

## Details

By default (`rank = NULL`) a taxon is the finest resolved label of each
record, which mixes ranks: a stomach with *Themisto libellula* and
"Amphipoda" counts two taxa although *Themisto* is an amphipod, so
`n_taxa` overstates richness, more so as digestion advances. Give `rank`
to count taxa at one stated rank instead, unidentified records excluded.

Note that a long prey-record table represents only non-empty stomachs,
so this function cannot report a vacuity (percent-empty) index; that
must be computed upstream from the full sampling frame.

## Examples

``` r
# the standard set-up: public ICES data, non-food items and nematodes dropped
phylum <- ices_lineage$phylum[match(ices_diet$prey_aphia_id, ices_lineage$prey_aphia_id)]
dat <- ices_diet[ices_diet$item_type != "non_food" & !phylum %in% "Nematoda", ]
spec <- dv_spec(
  predator       = "predator_common",
  predator_latin = "predator_latin",
  stomach        = "stomach_id",
  prey_id        = "prey_aphia_id",
  prey_name      = "prey_name",
  weight         = "prey_weight_g",
  count          = "prey_count",
  digestion      = "digestion_label",
  covariates     = c("region", "year", "quarter")
)
prep <- dv_prepare(dat, spec, taxonomy = "table", lineage = ices_lineage,
                   verbose = FALSE)
dv_summary(prep)
#>            predator_common n_stomachs n_records n_taxa records_per_stomach
#> 1        Atlantic mackerel       1048      1593     10                1.52
#> 2             Atlantic cod        991      2304    144                2.32
#> 3                  Whiting        892      1605    101                1.80
#> 4          European plaice        729      1890     69                2.59
#> 5  Atlantic horse mackerel        135       245     24                1.81
#> 6            European hake        106       154     23                1.45
#> 7              Tub gurnard         90       187     37                2.08
#> 8             Thorny skate         48       184     27                3.83
#> 9                   Turbot         47        87     21                1.85
#> 10                   Brill         26        51     15                1.96
#> 11                  Angler         20        37     11                1.85
#> 12            Grey gurnard         20        30      8                1.50
#> 13             Spotted ray         15        51     10                3.40
#> 14              Cuckoo ray         13        37      8                2.85
#> 15           Thornback ray         12        28      8                2.33
#> 16           Spiny dogfish         11        15      7                1.36
#> 17                 Pollack          9        17      8                1.89
#> 18                    Ling          4         4      4                1.00
#> 19        Atlantic halibut          2         4      3                2.00
#> 20              Blonde ray          2         3      2                1.50
#> 21           Smooth-hounds          1         1      1                1.00
#> 22     Starry smooth-hound          1         3      2                3.00
#>    total_weight
#> 1      2064.350
#> 2     10226.583
#> 3      2028.399
#> 4      1020.806
#> 5       104.532
#> 6      1863.367
#> 7       710.629
#> 8       117.484
#> 9       766.108
#> 10      201.074
#> 11     1699.026
#> 12       19.890
#> 13       40.759
#> 14       32.408
#> 15      146.465
#> 16      101.800
#> 17      366.663
#> 18      225.600
#> 19      125.943
#> 20        1.017
#> 21       11.793
#> 22       23.577
dv_summary(prep, by = "region")
#>            predator_common             region n_stomachs n_records n_taxa
#> 1        Atlantic mackerel          North Sea        948      1491     10
#> 2             Atlantic cod          North Sea        731      1739    116
#> 3                  Whiting          North Sea        650      1078     55
#> 4          European plaice          North Sea        429       955     47
#> 5          European plaice Skagerrak-Kattegat        262       874     43
#> 6             Atlantic cod         Baltic Sea        198       430     63
#> 7                  Whiting         Baltic Sea        167       410     62
#> 8        Atlantic mackerel Skagerrak-Kattegat        100       102      1
#> 9  Atlantic horse mackerel         Baltic Sea         91       187     23
#> 10                 Whiting Skagerrak-Kattegat         75       117     21
#> 11           European hake Skagerrak-Kattegat         72       116     16
#> 12            Atlantic cod Skagerrak-Kattegat         62       135     32
#> 13            Thorny skate Skagerrak-Kattegat         42       160     23
#> 14             Tub gurnard         Baltic Sea         39        75     25
#> 15 Atlantic horse mackerel          North Sea         38        51      6
#> 16         European plaice         Baltic Sea         38        61     11
#> 17             Tub gurnard          North Sea         38        77     10
#> 18                  Turbot          North Sea         36        66     16
#> 19           European hake          North Sea         34        38     13
#> 20            Grey gurnard          North Sea         20        30      8
#> 21                   Brill          North Sea         15        25      9
#> 22             Spotted ray          North Sea         15        51     10
#> 23                  Angler          North Sea         13        22      5
#> 24              Cuckoo ray          North Sea         13        37      8
#> 25             Tub gurnard Skagerrak-Kattegat         13        35     13
#> 26           Thornback ray          North Sea         11        27      7
#> 27                   Brill Skagerrak-Kattegat          7        20      9
#> 28           Spiny dogfish Skagerrak-Kattegat          7        10      5
#> 29                  Angler Skagerrak-Kattegat          6        14      8
#> 30 Atlantic horse mackerel Skagerrak-Kattegat          6         7      3
#> 31                  Turbot         Baltic Sea          6         8      5
#> 32                 Pollack          North Sea          5        11      4
#> 33            Thorny skate          North Sea          5        19      6
#> 34                  Turbot Skagerrak-Kattegat          5        13      8
#> 35                   Brill         Baltic Sea          4         6      5
#> 36                 Pollack Skagerrak-Kattegat          3         4      3
#> 37           Spiny dogfish          North Sea          3         4      2
#> 38        Atlantic halibut          North Sea          2         4      3
#> 39              Blonde ray          North Sea          2         3      2
#> 40                    Ling          North Sea          2         2      2
#> 41                    Ling Skagerrak-Kattegat          2         2      2
#> 42                  Angler         Baltic Sea          1         1      1
#> 43                 Pollack         Baltic Sea          1         2      2
#> 44           Smooth-hounds          North Sea          1         1      1
#> 45           Spiny dogfish         Baltic Sea          1         1      1
#> 46     Starry smooth-hound         Baltic Sea          1         3      2
#> 47           Thornback ray         Baltic Sea          1         1      1
#> 48            Thorny skate         Baltic Sea          1         5      5
#>    records_per_stomach total_weight
#> 1                 1.57    1905.3900
#> 2                 2.38    6498.5020
#> 3                 1.66    1371.9421
#> 4                 2.23     361.6340
#> 5                 3.34     651.6580
#> 6                 2.17    2817.3808
#> 7                 2.46     251.8765
#> 8                 1.02     158.9600
#> 9                 2.05      81.1310
#> 10                1.56     404.5800
#> 11                1.61    1139.4900
#> 12                2.18     910.7000
#> 13                3.81     111.9400
#> 14                1.92     388.3990
#> 15                1.34      19.7910
#> 16                1.61       7.5140
#> 17                2.03     178.8400
#> 18                1.83     670.7960
#> 19                1.12     723.8770
#> 20                1.50      19.8900
#> 21                1.67      98.7000
#> 22                3.40      40.7590
#> 23                1.69    1096.3830
#> 24                2.85      32.4080
#> 25                2.69     143.3900
#> 26                2.45     129.9740
#> 27                2.86      77.5800
#> 28                1.43       1.8200
#> 29                2.33     503.4000
#> 30                1.17       3.6100
#> 31                1.33      56.4820
#> 32                2.20     310.1100
#> 33                3.80       4.7220
#> 34                2.60      38.8300
#> 35                1.50      24.7940
#> 36                1.33      12.6700
#> 37                1.33      16.5710
#> 38                2.00     125.9430
#> 39                1.50       1.0170
#> 40                1.00     119.0700
#> 41                1.00     106.5300
#> 42                1.00      99.2430
#> 43                2.00      43.8830
#> 44                1.00      11.7930
#> 45                1.00      83.4090
#> 46                3.00      23.5770
#> 47                1.00      16.4910
#> 48                5.00       0.8220
head(dv_summary(prep, rank = "class"))
#>           predator_common n_stomachs n_records n_taxa records_per_stomach
#> 1       Atlantic mackerel       1048      1593      2                1.52
#> 2            Atlantic cod        991      2304     10                2.32
#> 3                 Whiting        892      1605      9                1.80
#> 4         European plaice        729      1890     14                2.59
#> 5 Atlantic horse mackerel        135       245      6                1.81
#> 6           European hake        106       154      3                1.45
#>   total_weight
#> 1     2064.350
#> 2    10226.583
#> 3     2028.399
#> 4     1020.806
#> 5      104.532
#> 6     1863.367
```
