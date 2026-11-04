# Delete the WoRMS and GBIF lookup caches

[`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md),
[`dv_taxonomy_worms()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_worms.md)
and
[`dv_taxonomy_gbif()`](https://sosthenea.github.io/DietView/reference/dv_taxonomy_gbif.md)
keep successful lookups in cache files (one per source), by default in
`tools::R_user_dir("DietView", "cache")`. Expired entries are removed
automatically; this function deletes the whole cache, and the cache
directory too if nothing else is left in it.

## Usage

``` r
dv_cache_clear(
  cache_dir = tools::R_user_dir("DietView", "cache"),
  source = c("all", "worms", "gbif")
)
```

## Arguments

- cache_dir:

  The cache directory, as given to
  [`dv_prepare()`](https://sosthenea.github.io/DietView/reference/dv_prepare.md).

- source:

  Which cache to delete: `"all"` (default), `"worms"` or `"gbif"`.

## Value

`TRUE` if a cache file was deleted, `FALSE` otherwise, invisibly.

## Examples

``` r
# a cache in a temporary folder, so the example leaves nothing behind
dir <- file.path(tempdir(), "dietview-cache")
dir.create(dir)
saveRDS(list(), file.path(dir, "worms_lineage.rds"))
dv_cache_clear(dir)
dir.exists(dir)
#> [1] FALSE
```
