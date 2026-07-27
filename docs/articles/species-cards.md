# Species identification cards and photos

Each predator in the dashboard gets an identification card with a photo
and a short description.
[`dv_species_card_assets()`](https://sosthenea.github.io/DietView/reference/dv_species_card_assets.md)
resolves those assets and returns a base64 data URI, so the dashboard
stays a single self-contained file.

## Resolution order

Photos are resolved in priority order, stopping at the first hit:

1.  an explicit local path you provide in `species_info`;
2.  a local file named after the predator (in `image_dir`);
3.  a local file named after the Latin name;
4.  a named Wikimedia Commons file;
5.  a Wikipedia thumbnail fetched by Latin name (or common name), cached
    to disk.

Descriptions come from an explicit string, a Wikipedia summary extract,
or a Commons image description. Every network lookup is wrapped so that
a failure degrades gracefully to a text-only card.

## Fully offline

Disable all network lookups with `use_wiki = FALSE` and supply your own
assets:

``` r
library(DietView)
info <- list(
  "Atlantic cod" = list(
    desc  = "Demersal gadid; opportunistic predator of fish and invertebrates.",
    photo = "images/atlantic_cod.jpg"
  ),
  "American plaice" = list(
    desc  = "Right-eyed flounder; feeds on brittle stars, polychaetes, and small crustaceans.",
    photo = "images/american_plaice.jpg"
  )
)
dv_build_html(prep, output = "diet_dashboard.html",
              species_info = info, image_dir = "images", use_wiki = FALSE)
```

## Calling the resolver directly

``` r
asset <- dv_species_card_assets(
  predator = "Atlantic cod", latin = "Gadus morhua",
  image_dir = "images", use_wiki = TRUE)
str(asset)   # list(uri = <data URI>, desc = <text>, credit = <attribution>)
```

Please respect image licences: when a photo comes from
Wikimedia/Wikipedia, the returned `credit` field carries the attribution
to display.
