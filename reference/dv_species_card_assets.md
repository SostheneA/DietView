# Resolve an identification photo and description for a predator

Builds the photo, description and credit line of one predator card in
the dashboard
([`dv_build_html()`](https://sosthenea.github.io/DietView/reference/dv_build_html.md)).
It handles one predator at a time, and the card carries no taxonomic
lineage. Looks for a photo in this priority order:

1.  an explicit local path in `info$photo`

2.  a local file in `image_dir` named after the predator

3.  a local file in `image_dir` named after the Latin name

4.  the online sources named in `photo_source`, tried in the order given
    until one returns a photo:

    - `"inaturalist"`: a photo of the taxon on iNaturalist (the taxon's
      default photo, else the first of its other photos) whose license
      is in `licenses`

    - `"wikipedia"`: a Wikimedia Commons file declared in
      `info$commons_file`, else the Wikipedia thumbnail for the Latin
      name (or predator name), used only when it is a Wikimedia Commons
      file

## Usage

``` r
dv_species_card_assets(
  predator,
  latin = NA,
  info = NULL,
  image_dir = file.path(tempdir(), "dietview-images"),
  photo_source = "none",
  licenses = c("cc0", "cc-by", "cc-by-sa"),
  use_wiki = NULL
)
```

## Arguments

- predator:

  Common name (used for the local file name and alt text).

- latin:

  Latin name (used for the online lookups).

- info:

  Optional list for this predator, with any of `photo`, `desc`,
  `credit`, `author`, `license`, `url` and `commons_file`.

- image_dir:

  Folder holding/caching images. Defaults to a folder in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html); give a permanent
  folder to keep downloads between sessions.

- photo_source:

  Where to look online when no local file is found: `"none"` (default:
  no network access), or one or more of `"inaturalist"` and
  `"wikipedia"` (Wikipedia and Wikimedia Commons), tried in that order,
  e.g. `c("inaturalist", "wikipedia")`. Each request times out after
  `getOption("DietView.timeout", 15)` seconds.

- licenses:

  iNaturalist license codes accepted for a photo. The default keeps the
  licenses that allow redistribution with attribution: `"cc0"`,
  `"cc-by"` and `"cc-by-sa"`. Add `"cc-by-nc"` (and `"cc-by-nc-sa"`,
  `"cc-by-nd"`, `"cc-by-nc-nd"`) only if the dashboard will be shared
  for non-commercial use and the license terms suit you.

- use_wiki:

  Deprecated. `TRUE` means `photo_source = "wikipedia"`, `FALSE` means
  `photo_source = "none"`.

## Value

A list with `uri` (data URI or NULL), `path` (the image file, or NULL),
`desc`, `desc_credit` (credit for the description text), `credit` (photo
credit line, e.g. `"Photo: Jane Doe, CC BY, via iNaturalist"`),
`author`, `license`, `source` (`"local"`, `"inaturalist"` or
`"wikimedia"`) and `url` (the photo page); each element is NULL when
unknown.

## Details

Every photo fetched online carries its author and license. An
iNaturalist photo whose license is not in `licenses` (including "all
rights reserved") is never used. A Commons image is kept only when
Commons reports its license, and Wikipedia thumbnails hosted outside
Commons, which may be non-free files, are never used.

Downloads are cached in `image_dir`, each with a small `.json` file
holding its source, author, license and page URL, so a cached photo
keeps its credit line in later sessions. A local photo can carry the
same fields: put them in `info` (`credit`, `author`, `license`, `url`)
or in a `.json` file of the same name next to the image. Delete the
image and its `.json` file to fetch it again.

Description priority:

1.  `info$desc`

2.  the Wikipedia summary, as returned by iNaturalist or by Wikipedia
    (text under CC BY-SA, credited in `desc_credit`)

3.  the Wikimedia Commons image description (with
    `photo_source = "wikipedia"`)

With `photo_source = "none"` (the default) nothing is fetched: with no
local file, the result has no image and only the description given in
`info`.

Returns a base64 data URI so the dashboard stays self-contained.

## Examples

``` r
# offline: no photo resolved, returns a text-only card structure
dv_species_card_assets("Atlantic cod", image_dir = tempdir())
#> $uri
#> NULL
#> 
#> $path
#> NULL
#> 
#> $desc
#> NULL
#> 
#> $desc_credit
#> NULL
#> 
#> $credit
#> NULL
#> 
#> $author
#> NULL
#> 
#> $license
#> NULL
#> 
#> $source
#> NULL
#> 
#> $url
#> NULL
#> 
if (FALSE) { # \dontrun{
# online: an openly licensed iNaturalist photo, with author and license
a <- dv_species_card_assets("Atlantic cod", latin = "Gadus morhua",
                            photo_source = "inaturalist",
                            image_dir = tempdir())
a$credit
} # }
```
