#' Resolve an identification photo and description for a predator
#'
#' Builds the photo, description and credit line of one predator card in the
#' dashboard ([dv_build_html()]). It handles one predator at a time, and the
#' card carries no taxonomic lineage. Looks for a photo in this priority order:
#' 1) an explicit local path in `info$photo`
#' 2) a local file in `image_dir` named after the predator
#' 3) a local file in `image_dir` named after the Latin name
#' 4) the online sources named in `photo_source`, tried in the order given
#'    until one returns a photo:
#'    - `"inaturalist"`: a photo of the taxon on iNaturalist (the taxon's
#'      default photo, else the first of its other photos) whose license is in
#'      `licenses`
#'    - `"wikipedia"`: a Wikimedia Commons file declared in `info$commons_file`,
#'      else the Wikipedia thumbnail for the Latin name (or predator name), used
#'      only when it is a Wikimedia Commons file
#'
#' Every photo fetched online carries its author and license. An iNaturalist
#' photo whose license is not in `licenses` (including "all rights reserved")
#' is never used. A Commons image is kept only when Commons reports its
#' license, and Wikipedia thumbnails hosted outside Commons, which may be
#' non-free files, are never used.
#'
#' Downloads are cached in `image_dir`, each with a small `.json` file holding
#' its source, author, license and page URL, so a cached photo keeps its credit
#' line in later sessions. A local photo can carry the same fields: put them in
#' `info` (`credit`, `author`, `license`, `url`) or in a `.json` file of the same
#' name next to the image. Delete the image and its `.json` file to fetch it
#' again.
#'
#' Description priority:
#' 1) `info$desc`
#' 2) the Wikipedia summary, as returned by iNaturalist or by Wikipedia (text
#'    under CC BY-SA, credited in `desc_credit`)
#' 3) the Wikimedia Commons image description (with `photo_source = "wikipedia"`)
#'
#' With `photo_source = "none"` (the default) nothing is fetched: with no local
#' file, the result has no image and only the description given in `info`.
#'
#' Returns a base64 data URI so the dashboard stays self-contained.
#'
#' @param predator Common name (used for the local file name and alt text).
#' @param latin Latin name (used for the online lookups).
#' @param info Optional list for this predator, with any of `photo`, `desc`,
#'   `credit`, `author`, `license`, `url` and `commons_file`.
#' @param image_dir Folder holding/caching images. Defaults to a folder in
#'   [tempdir()]; give a permanent folder to keep downloads between sessions.
#' @param photo_source Where to look online when no local file is found:
#'   `"none"` (default: no network access), or one or more of `"inaturalist"`
#'   and `"wikipedia"` (Wikipedia and Wikimedia Commons), tried in that order,
#'   e.g. `c("inaturalist", "wikipedia")`. Each request times out after
#'   `getOption("DietView.timeout", 15)` seconds.
#' @param licenses iNaturalist license codes accepted for a photo. The default
#'   keeps the licenses that allow redistribution with attribution: `"cc0"`,
#'   `"cc-by"` and `"cc-by-sa"`. Add `"cc-by-nc"` (and `"cc-by-nc-sa"`,
#'   `"cc-by-nd"`, `"cc-by-nc-nd"`) only if the dashboard will be shared for
#'   non-commercial use and the license terms suit you.
#' @param use_wiki Deprecated. `TRUE` means `photo_source = "wikipedia"`,
#'   `FALSE` means `photo_source = "none"`.
#' @return A list with `uri` (data URI or NULL), `path` (the image file, or
#'   NULL), `desc`, `desc_credit` (credit
#'   for the description text), `credit` (photo credit line, e.g.
#'   `"Photo: Jane Doe, CC BY, via iNaturalist"`), `author`, `license`,
#'   `source` (`"local"`, `"inaturalist"` or `"wikimedia"`) and `url` (the
#'   photo page); each element is NULL when unknown.
#' @examples
#' # offline: no photo resolved, returns a text-only card structure
#' dv_species_card_assets("Atlantic cod", image_dir = tempdir())
#' \dontrun{
#' # online: an openly licensed iNaturalist photo, with author and license
#' a <- dv_species_card_assets("Atlantic cod", latin = "Gadus morhua",
#'                             photo_source = "inaturalist",
#'                             image_dir = tempdir())
#' a$credit
#' }
#' @export
dv_species_card_assets <- function(predator, latin = NA, info = NULL,
                                   image_dir = file.path(tempdir(), "dietview-images"),
                                   photo_source = "none",
                                   licenses = c("cc0", "cc-by", "cc-by-sa"),
                                   use_wiki = NULL) {

  if (!is.null(use_wiki) && missing(photo_source)) {
    message("`use_wiki` is deprecated; use `photo_source = \"",
            if (isTRUE(use_wiki)) "wikipedia" else "none", "\"` instead.")
    photo_source <- if (isTRUE(use_wiki)) "wikipedia" else "none"
  }
  photo_source <- match.arg(photo_source, c("none", "inaturalist", "wikipedia"),
                            several.ok = TRUE)
  if ("none" %in% photo_source) {
    if (length(photo_source) > 1) {
      stop("`photo_source = \"none\"` cannot be combined with other sources.",
           call. = FALSE)
    }
    photo_source <- character(0)
  }
  if (length(photo_source)) {
    old <- options(timeout = getOption("DietView.timeout", 15))
    on.exit(options(old), add = TRUE)
  }
  licenses <- tolower(licenses)
  bad <- setdiff(licenses, names(.dv_inat_licenses))
  if (length(bad)) {
    stop("Unknown iNaturalist license code(s): ", paste(bad, collapse = ", "),
         ". Use any of: ", paste(names(.dv_inat_licenses), collapse = ", "), ".",
         call. = FALSE)
  }

  `%||%` <- function(a, b) {
    if (!is.null(a) && length(a) && !all(is.na(a))) a else b
  }

  null_if_empty <- function(x) {
    if (is.null(x) || !length(x) || all(is.na(x))) return(NULL)
    x <- as.character(x)[1]
    x <- trimws(x)
    if (!nzchar(x) || identical(x, "NA")) return(NULL)
    x
  }

  strip_html <- function(x) {
    x <- null_if_empty(x)
    if (is.null(x)) return(NULL)
    x <- gsub("<[^>]+>", "", x)
    x <- gsub("&nbsp;", " ", x, fixed = TRUE)
    x <- gsub("&amp;", "&", x, fixed = TRUE)
    x <- gsub("&quot;", "\"", x, fixed = TRUE)
    x <- gsub("&#39;", "'", x, fixed = TRUE)
    x <- trimws(x)
    if (!nzchar(x)) NULL else x
  }

  if (!dir.exists(image_dir)) {
    dir.create(image_dir, recursive = TRUE, showWarnings = FALSE)
  }

  field <- function(name) if (!is.null(info)) null_if_empty(info[[name]]) else NULL
  desc        <- field("desc")
  desc_credit <- NULL
  meta <- list(credit = field("credit"), author = field("author"),
               license = field("license"), url = field("url"), source = NULL)

  img_ext <- c("jpg", "jpeg", "png", "webp")

  # credit fields stored next to an image (written for every download)
  read_sidecar <- function(img) {
    js <- paste0(tools::file_path_sans_ext(img), ".json")
    if (!file.exists(js)) return(NULL)
    tryCatch(jsonlite::fromJSON(js, simplifyVector = FALSE), error = function(e) NULL)
  }

  # fill credit fields from a sidecar or a lookup, keeping values given in info
  take_meta <- function(m) {
    if (is.null(m)) return(invisible())
    for (k in c("credit", "author", "license", "url", "source")) {
      if (is.null(meta[[k]])) meta[[k]] <<- null_if_empty(m[[k]])
    }
    invisible()
  }

  find_local <- function() {
    photo <- field("photo")
    if (!is.null(photo) && file.exists(photo)) return(photo)

    for (nm in c(predator, if (!is.na(latin) && nzchar(latin)) latin)) {
      cand <- file.path(image_dir, paste0(.dv_slugify(nm), ".", img_ext))
      hit <- cand[file.exists(cand)]
      if (length(hit)) return(hit[1])
    }
    NULL
  }

  wiki_summary <- function(title) {
    title <- null_if_empty(title)
    if (is.null(title)) return(NULL)

    title_enc <- utils::URLencode(gsub(" ", "_", title), reserved = TRUE)
    js <- .dv_get_json(paste0("https://en.wikipedia.org/api/rest_v1/page/summary/",
                              title_enc))
    if (is.null(js)) return(NULL)
    list(
      desc = null_if_empty(js$extract),
      src  = null_if_empty(js$thumbnail$source %||% js$originalimage$source)
    )
  }

  commons_info <- function(file_title, thumb_width = 500) {
    file_title <- null_if_empty(file_title)
    if (is.null(file_title)) return(NULL)

    if (!grepl("^File:", file_title, ignore.case = TRUE)) {
      file_title <- paste0("File:", file_title)
    }

    js <- .dv_get_json(paste0(
      "https://commons.wikimedia.org/w/api.php",
      "?action=query",
      "&format=json",
      "&origin=*",
      "&prop=imageinfo",
      "&iiprop=url|extmetadata",
      "&iiurlwidth=", thumb_width,
      "&titles=", utils::URLencode(file_title, reserved = TRUE)
    ))
    pages <- js$query$pages
    if (is.null(pages) || !length(pages)) return(NULL)

    ii <- pages[[1]]$imageinfo[[1]]
    if (is.null(ii)) return(NULL)

    em <- ii$extmetadata
    meta_val <- function(name) {
      if (is.null(em[[name]]$value)) return(NULL)
      strip_html(em[[name]]$value)
    }

    artist  <- meta_val("Artist")
    license <- meta_val("LicenseShortName")

    list(
      src     = null_if_empty(ii$thumburl %||% ii$url),
      desc    = meta_val("ImageDescription"),
      author  = artist,
      license = license,
      url     = null_if_empty(ii$descriptionurl),
      credit  = .dv_credit_line(artist, license, "Wikimedia Commons")
    )
  }

  # an iNaturalist photo object -> credit fields, or NULL if its license is
  # not accepted (a missing license code means "all rights reserved")
  inat_photo <- function(ph) {
    code <- tolower(null_if_empty(ph$license_code) %||% "")
    if (!code %in% licenses) return(NULL)
    src <- null_if_empty(ph$medium_url %||% ph$url)
    if (is.null(src)) return(NULL)
    src <- sub("/square\\.", "/medium.", src)
    author <- null_if_empty(ph$attribution_name) %||%
      .dv_inat_author(null_if_empty(ph$attribution))
    license <- .dv_inat_licenses[[code]]
    list(
      src     = src,
      author  = author,
      license = license,
      url     = if (!is.null(ph$id)) paste0("https://www.inaturalist.org/photos/", ph$id),
      credit  = .dv_credit_line(author, license, "iNaturalist",
                                fallback = null_if_empty(ph$attribution))
    )
  }

  # look the taxon up by Latin name (or common name), never taking a taxon
  # whose name does not match the query
  inat_lookup <- function(query) {
    query <- null_if_empty(query)
    if (is.null(query)) return(NULL)
    js <- .dv_get_json(paste0("https://api.inaturalist.org/v1/taxa?per_page=10&q=",
                              utils::URLencode(query, reserved = TRUE)))
    res <- js$results
    if (is.null(res) || !length(res)) return(NULL)
    q <- tolower(query)
    hit <- Filter(function(t) {
      tolower(t$name %||% "") == q || tolower(t$matched_term %||% "") == q
    }, res)
    if (!length(hit)) return(NULL)
    tx <- hit[[1]]

    # the full record carries the other photos and the Wikipedia summary
    full <- .dv_get_json(paste0("https://api.inaturalist.org/v1/taxa/", tx$id))
    full <- if (!is.null(full$results) && length(full$results)) full$results[[1]] else tx

    photos <- c(list(full$default_photo %||% tx$default_photo),
                lapply(full$taxon_photos %||% list(), function(tp) tp$photo))
    photo <- NULL
    for (ph in photos) {
      if (is.null(ph)) next
      photo <- inat_photo(ph)
      if (!is.null(photo)) break
    }
    list(photo = photo, desc = strip_html(full$wikipedia_summary),
         wikipedia_url = null_if_empty(full$wikipedia_url))
  }

  download_cached <- function(src, slug_base, m) {
    src <- null_if_empty(src)
    slug_base <- null_if_empty(slug_base)
    if (is.null(src) || is.null(slug_base)) return(NULL)

    slug <- .dv_slugify(slug_base)
    ext <- tolower(tools::file_ext(sub("\\?.*$", "", src)))
    if (!ext %in% img_ext) ext <- "jpg"
    dest <- file.path(image_dir, paste0(slug, ".", ext))

    if (!.dv_download(src, dest)) return(NULL)
    jsonlite::write_json(m[c("source", "author", "license", "url", "credit")],
                         paste0(tools::file_path_sans_ext(dest), ".json"),
                         auto_unbox = TRUE, null = "null", pretty = TRUE)
    dest
  }

  # Commons file name behind an upload.wikimedia.org/wikipedia/commons/ URL
  # (original or thumbnail); NULL for any other host, e.g. en.wikipedia files
  commons_file_from_url <- function(src) {
    src <- null_if_empty(src)
    if (is.null(src)) return(NULL)
    rx <- "^https?://upload\\.wikimedia\\.org/wikipedia/commons/(thumb/)?[0-9a-f]/[0-9a-f]{2}/([^/?]+).*$"
    if (!grepl(rx, src)) return(NULL)
    utils::URLdecode(sub(rx, "\\2", src))
  }

  # download a Commons image only when its license is known; credit always set
  use_commons <- function(file_title) {
    cm <- commons_info(file_title)
    if (is.null(cm) || is.null(cm$license) || is.null(cm$src)) return(FALSE)
    cm$source <- "wikimedia"
    p <- download_cached(cm$src, lookup_name, cm)
    if (is.null(p)) return(FALSE)
    path <<- p
    take_meta(cm)
    if (is.null(desc)) desc <<- cm$desc
    TRUE
  }

  lookup_name <- if (!is.na(latin) && nzchar(latin)) latin else predator

  path <- find_local()
  if (!is.null(path)) {
    take_meta(read_sidecar(path))
    if (is.null(meta$source)) meta$source <- "local"
  }

  for (src in photo_source) {
    if (!is.null(path) && !is.null(desc)) break

    if (src == "inaturalist") {
      tx <- inat_lookup(lookup_name)
      if (!is.null(tx)) {
        if (is.null(desc) && !is.null(tx$desc)) {
          desc <- tx$desc
          desc_credit <- "Text: Wikipedia, CC BY-SA, via iNaturalist"
        }
        if (is.null(path) && !is.null(tx$photo)) {
          tx$photo$source <- "inaturalist"
          p <- download_cached(tx$photo$src, lookup_name, tx$photo)
          if (!is.null(p)) {
            path <- p
            take_meta(tx$photo)
          }
        }
      }
    }

    if (src == "wikipedia") {
      ws <- wiki_summary(lookup_name)   # one call
      if (!is.null(ws) && is.null(desc) && !is.null(ws$desc)) {
        desc <- ws$desc
        desc_credit <- "Text: Wikipedia, CC BY-SA"
      }
      if (is.null(path) && !is.null(field("commons_file"))) {
        use_commons(field("commons_file"))
      }
      if (is.null(path) && !is.null(ws) && !is.null(ws$src)) {
        cf <- commons_file_from_url(ws$src)
        if (!is.null(cf)) use_commons(cf)
      }
    }
  }

  if (is.null(meta$credit) && !is.null(meta$author)) {
    meta$credit <- .dv_credit_line(meta$author, meta$license, NULL)
  }

  uri <- if (!is.null(path)) {
    tryCatch(knitr::image_uri(path), error = function(e) NULL)
  } else {
    NULL
  }
  if (is.null(uri)) {
    path <- NULL
    meta[c("credit", "author", "license", "url", "source")] <- list(NULL)
  }

  list(uri = uri, path = path, desc = desc, desc_credit = desc_credit,
       credit = meta$credit, author = meta$author, license = meta$license,
       source = meta$source, url = meta$url)
}

# iNaturalist license codes and how they are written in a credit line
.dv_inat_licenses <- c(
  "cc0"         = "CC0",
  "cc-by"       = "CC BY",
  "cc-by-sa"    = "CC BY-SA",
  "cc-by-nd"    = "CC BY-ND",
  "cc-by-nc"    = "CC BY-NC",
  "cc-by-nc-sa" = "CC BY-NC-SA",
  "cc-by-nc-nd" = "CC BY-NC-ND"
)

# "(c) Jane Doe, some rights reserved (CC BY)" -> "Jane Doe"
.dv_inat_author <- function(attribution) {
  if (is.null(attribution)) return(NULL)
  a <- sub("^\\(c\\)\\s*", "", attribution)
  a <- sub(",\\s*(some|all|no) rights reserved.*$", "", a, ignore.case = TRUE)
  a <- trimws(a)
  if (nzchar(a) && !grepl("^no rights reserved", a, ignore.case = TRUE)) a else NULL
}

# "Photo: Jane Doe, CC BY, via iNaturalist"
.dv_credit_line <- function(author, license, via, fallback = NULL) {
  parts <- c(author, license)
  if (!length(parts)) return(fallback)
  line <- paste0("Photo: ", paste(parts, collapse = ", "))
  if (!is.null(via)) line <- paste0(line, ", via ", via)
  line
}

# network helpers, kept separate so the tests can replace them
.dv_get_json <- function(url) {
  tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE),
           error = function(e) NULL)
}

.dv_download <- function(src, dest) {
  tryCatch({
    utils::download.file(src, dest, mode = "wb", quiet = TRUE)
    file.exists(dest) && file.info(dest)$size > 0
  }, error = function(e) FALSE)
}
