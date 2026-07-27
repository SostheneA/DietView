#' Resolve an identification photo and description for a predator
#'
#' Looks for a photo in this priority order:
#' 1) an explicit local path in `info$photo`
#' 2) a local file in `image_dir` named after the predator
#' 3) a local file in `image_dir` named after the Latin name
#' 4) a Wikimedia Commons file declared in `info$commons_file`
#' 5) a Wikipedia thumbnail fetched by Latin name (or predator name) and cached
#'
#' Description priority:
#' 1) `info$desc`
#' 2) Wikipedia summary extract by Latin name (or predator name)
#' 3) Wikimedia Commons image description fallback
#'
#' Returns a base64 data URI so the dashboard stays self-contained.
#'
#' @param predator Common name (used for the local file slug and alt text).
#' @param latin Latin name (used for the Wikipedia lookup).
#' @param info Optional list with `photo`, `desc`, `commons_file`, and/or `credit`
#'   for this predator.
#' @param image_dir Folder holding/caching images.
#' @param use_wiki Whether to auto-fetch from Wikipedia / Wikimedia Commons when
#'   no local file is found.
#' @return A list with `uri` (data URI or NULL), `desc` (string or NULL), and
#'   `credit` (string or NULL).
#' @examples
#' # offline: no photo resolved, returns a text-only card structure
#' dv_species_card_assets("Atlantic cod", use_wiki = FALSE,
#'                        image_dir = tempdir())
#' \dontrun{
#' # online: fetch a Wikipedia thumbnail by Latin name
#' dv_species_card_assets("Atlantic cod", latin = "Gadus morhua",
#'                        use_wiki = TRUE, image_dir = tempdir())
#' }
#' @export
dv_species_card_assets <- function(predator, latin = NA, info = NULL,
                                   image_dir = "images", use_wiki = TRUE) {

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

  desc   <- if (!is.null(info) && !is.null(info$desc)) null_if_empty(info$desc) else NULL
  credit <- if (!is.null(info) && !is.null(info$credit)) null_if_empty(info$credit) else NULL

  find_local <- function() {
    if (!is.null(info) && !is.null(info$photo) && file.exists(info$photo)) {
      return(info$photo)
    }

    cand1 <- file.path(image_dir, paste0(.dv_slugify(predator),
                                         c(".jpg", ".jpeg", ".png", ".webp")))
    hit1 <- cand1[file.exists(cand1)]
    if (length(hit1)) return(hit1[1])

    if (!is.na(latin) && nzchar(latin)) {
      cand2 <- file.path(image_dir, paste0(.dv_slugify(latin),
                                           c(".jpg", ".jpeg", ".png", ".webp")))
      hit2 <- cand2[file.exists(cand2)]
      if (length(hit2)) return(hit2[1])
    }

    NULL
  }

  wiki_summary <- function(title) {
    title <- null_if_empty(title)
    if (is.null(title)) return(NULL)

    title_enc <- utils::URLencode(gsub(" ", "_", title), reserved = TRUE)
    url <- paste0("https://en.wikipedia.org/api/rest_v1/page/summary/", title_enc)

    tryCatch({
      js <- jsonlite::fromJSON(url)
      list(
        desc = null_if_empty(js$extract),
        src  = null_if_empty(js$thumbnail$source %||% js$originalimage$source)
      )
    }, error = function(e) NULL)
  }

  commons_info <- function(file_title, thumb_width = 500) {
    file_title <- null_if_empty(file_title)
    if (is.null(file_title)) return(NULL)

    if (!grepl("^File:", file_title, ignore.case = TRUE)) {
      file_title <- paste0("File:", file_title)
    }

    url <- paste0(
      "https://commons.wikimedia.org/w/api.php",
      "?action=query",
      "&format=json",
      "&origin=*",
      "&prop=imageinfo",
      "&iiprop=url|extmetadata",
      "&iiurlwidth=", thumb_width,
      "&titles=", utils::URLencode(file_title, reserved = TRUE)
    )

    tryCatch({
      js <- jsonlite::fromJSON(url, simplifyVector = FALSE)
      pages <- js$query$pages
      if (is.null(pages) || !length(pages)) return(NULL)

      pg <- pages[[1]]
      ii <- pg$imageinfo[[1]]
      if (is.null(ii)) return(NULL)

      meta <- ii$extmetadata
      meta_val <- function(name) {
        if (is.null(meta[[name]]$value)) return(NULL)
        strip_html(meta[[name]]$value)
      }

      artist  <- meta_val("Artist")
      license <- meta_val("LicenseShortName")
      imgdesc <- meta_val("ImageDescription")

      credit_parts <- c(artist, license)
      credit_parts <- credit_parts[!vapply(credit_parts, is.null, logical(1))]
      credit_txt <- if (length(credit_parts)) paste(credit_parts, collapse = " - ") else NULL

      list(
        src    = null_if_empty(ii$thumburl %||% ii$url),
        desc   = imgdesc,
        credit = credit_txt
      )
    }, error = function(e) NULL)
  }

  download_cached <- function(src, slug_base) {
    src <- null_if_empty(src)
    slug_base <- null_if_empty(slug_base)
    if (is.null(src) || is.null(slug_base)) return(NULL)

    slug <- .dv_slugify(slug_base)
    cached <- list.files(image_dir, pattern = paste0("^", slug, "\\."), full.names = TRUE)
    if (length(cached)) return(cached[1])

    ext <- tools::file_ext(sub("\\?.*$", "", src))
    if (!nzchar(ext)) ext <- "jpg"

    dest <- file.path(image_dir, paste0(slug, ".", tolower(ext)))

    ok <- tryCatch({
      utils::download.file(src, dest, mode = "wb", quiet = TRUE)
      file.exists(dest) && file.info(dest)$size > 0
    }, error = function(e) FALSE)

    if (ok) dest else NULL
  }

  lookup_name <- if (!is.na(latin) && nzchar(latin)) latin else predator

  path <- find_local()

  if (isTRUE(use_wiki) && is.null(desc)) {
    ws <- wiki_summary(lookup_name)
    if (!is.null(ws)) desc <- desc %||% ws$desc
  }

  if (isTRUE(use_wiki) && is.null(path) &&
      !is.null(info) && !is.null(info$commons_file)) {
    cm <- commons_info(info$commons_file)
    if (!is.null(cm)) {
      path <- download_cached(cm$src, lookup_name)
      credit <- credit %||% cm$credit
      if (is.null(desc)) desc <- cm$desc
    }
  }

  if (isTRUE(use_wiki) && is.null(path)) {
    ws <- wiki_summary(lookup_name)
    if (!is.null(ws) && !is.null(ws$src)) {
      path <- download_cached(ws$src, lookup_name)
    }
  }

  uri <- if (!is.null(path)) {
    tryCatch(knitr::image_uri(path), error = function(e) NULL)
  } else {
    NULL
  }

  list(uri = uri, desc = desc, credit = credit)
}
