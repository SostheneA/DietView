# Resolve an identification photo and description for a predator

Looks for a photo in this priority order:

1.  an explicit local path in `info$photo`

2.  a local file in `image_dir` named after the predator

3.  a local file in `image_dir` named after the Latin name

4.  a Wikimedia Commons file declared in `info$commons_file`

5.  a Wikipedia thumbnail fetched by Latin name (or predator name) and
    cached

## Usage

``` r
dv_species_card_assets(
  predator,
  latin = NA,
  info = NULL,
  image_dir = "images",
  use_wiki = TRUE
)
```

## Arguments

- predator:

  Common name (used for the local file slug and alt text).

- latin:

  Latin name (used for the Wikipedia lookup).

- info:

  Optional list with `photo`, `desc`, `commons_file`, and/or `credit`
  for this predator.

- image_dir:

  Folder holding/caching images.

- use_wiki:

  Whether to auto-fetch from Wikipedia / Wikimedia Commons when no local
  file is found.

## Value

A list with `uri` (data URI or NULL), `desc` (string or NULL), and
`credit` (string or NULL).

## Details

Description priority:

1.  `info$desc`

2.  Wikipedia summary extract by Latin name (or predator name)

3.  Wikimedia Commons image description fallback

Returns a base64 data URI so the dashboard stays self-contained.

## Examples

``` r
# offline: no photo resolved, returns a text-only card structure
dv_species_card_assets("Atlantic cod", use_wiki = FALSE,
                       image_dir = tempdir())
#> $uri
#> NULL
#> 
#> $desc
#> NULL
#> 
#> $credit
#> NULL
#> 
if (FALSE) { # \dontrun{
# online: fetch a Wikipedia thumbnail by Latin name
dv_species_card_assets("Atlantic cod", latin = "Gadus morhua",
                       use_wiki = TRUE, image_dir = tempdir())
} # }
```
