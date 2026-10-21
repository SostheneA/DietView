# Offline tests of the photo resolver: the iNaturalist and Wikimedia APIs are
# replaced by canned responses, and "downloads" write a few bytes.

inat_search <- function(photo) {
  list(results = list(
    list(id = 1, name = "Gadus", matched_term = "Gadus"),       # not the query
    list(id = 8336, name = "Gadus morhua", matched_term = "Gadus morhua",
         default_photo = photo)))
}

inat_full <- function(default_photo, others = list()) {
  list(results = list(list(
    id = 8336, name = "Gadus morhua",
    wikipedia_summary = "The <b>Atlantic cod</b> is a benthopelagic fish.",
    wikipedia_url = "https://en.wikipedia.org/wiki/Atlantic_cod",
    default_photo = default_photo,
    taxon_photos = lapply(others, function(p) list(photo = p)))))
}

photo <- function(id, code, name = "Jane Doe") {
  list(id = id, license_code = code, attribution_name = name,
       attribution = paste0("(c) ", name, ", some rights reserved (",
                            toupper(code %||% "none"), ")"),
       medium_url = paste0("https://inaturalist-open-data.s3.amazonaws.com/photos/",
                           id, "/medium.jpg"))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

mock_inat <- function(search, full, env = parent.frame()) {
  calls <- new.env()
  calls$urls <- character()
  local_mocked_bindings(
    .dv_get_json = function(url) {
      calls$urls <- c(calls$urls, url)
      if (grepl("/v1/taxa\\?", url)) search
      else if (grepl("/v1/taxa/8336$", url)) full
      else NULL
    },
    .dv_download = function(src, dest) {
      writeBin(as.raw(c(0x89, 0x50, 0x4e, 0x47)), dest)
      TRUE
    },
    .env = env)
  calls
}

test_that("an openly licensed iNaturalist photo comes with author and license", {
  dir <- withr::local_tempdir()
  p <- photo(111, "cc-by")
  mock_inat(inat_search(p), inat_full(p))
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                              photo_source = "inaturalist")
  expect_false(is.null(a$uri))
  expect_equal(a$author, "Jane Doe")
  expect_equal(a$license, "CC BY")
  expect_equal(a$source, "inaturalist")
  expect_equal(a$url, "https://www.inaturalist.org/photos/111")
  expect_equal(a$credit, "Photo: Jane Doe, CC BY, via iNaturalist")
  expect_equal(a$desc, "The Atlantic cod is a benthopelagic fish.")
  expect_match(a$desc_credit, "Wikipedia, CC BY-SA")
})

test_that("photos outside the accepted licenses are skipped, never used", {
  dir <- withr::local_tempdir()
  arr   <- photo(1, NULL, "Rights Reserved")      # all rights reserved
  nc    <- photo(2, "cc-by-nc", "Non Commercial")
  ok    <- photo(3, "cc0", "Free Person")
  mock_inat(inat_search(arr), inat_full(arr, list(nc, ok)))
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                              photo_source = "inaturalist")
  expect_equal(a$author, "Free Person")
  expect_equal(a$license, "CC0")

  # accepting CC BY-NC explicitly picks the first photo that qualifies
  dir2 <- withr::local_tempdir()
  b <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir2,
                              photo_source = "inaturalist",
                              licenses = c("cc0", "cc-by", "cc-by-nc"))
  expect_equal(b$author, "Non Commercial")
  expect_equal(b$license, "CC BY-NC")
})

test_that("no acceptable photo means no photo, but the description is kept", {
  dir <- withr::local_tempdir()
  arr <- photo(1, NULL)
  mock_inat(inat_search(arr), inat_full(arr))
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                              photo_source = "inaturalist")
  expect_null(a$uri)
  expect_null(a$credit)
  expect_null(a$license)
  expect_false(is.null(a$desc))
  expect_length(list.files(dir), 0)
})

test_that("a taxon whose name does not match the query is not used", {
  dir <- withr::local_tempdir()
  wrong <- list(results = list(list(id = 1, name = "Gadus", matched_term = "Gadus",
                                    default_photo = photo(1, "cc-by"))))
  mock_inat(wrong, NULL)
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                              photo_source = "inaturalist")
  expect_null(a$uri)
  expect_null(a$desc)
})

test_that("a cached photo keeps its credit without any network call", {
  dir <- withr::local_tempdir()
  p <- photo(111, "cc-by-sa", "Cached Author")
  mock_inat(inat_search(p), inat_full(p))
  dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                         photo_source = "inaturalist")
  expect_true(file.exists(file.path(dir, "gadus_morhua.json")))

  calls <- mock_inat(NULL, NULL)
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir)
  expect_length(calls$urls, 0)
  expect_false(is.null(a$uri))
  expect_equal(a$credit, "Photo: Cached Author, CC BY-SA, via iNaturalist")
  expect_equal(a$source, "inaturalist")
})

test_that("offline by default, and credit given in info is used for local photos", {
  dir <- withr::local_tempdir()
  calls <- mock_inat(NULL, NULL)
  img <- file.path(dir, "cod.jpg")
  writeBin(as.raw(1:4), img)
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                              info = list(photo = img, author = "Me", license = "CC BY"))
  expect_length(calls$urls, 0)
  expect_equal(a$credit, "Photo: Me, CC BY")
  expect_equal(a$source, "local")
})

test_that("bad license codes and the deprecated use_wiki are handled", {
  expect_error(dv_species_card_assets("Atlantic cod", licenses = "cc-by-4.0"),
               "Unknown iNaturalist license")
  dir <- withr::local_tempdir()
  calls <- mock_inat(NULL, NULL)
  expect_message(dv_species_card_assets("Atlantic cod", image_dir = dir,
                                        use_wiki = FALSE),
                 "deprecated")
  expect_length(calls$urls, 0)
})

test_that("the dashboard card shows the linked credit line", {
  dir <- withr::local_tempdir()
  p <- photo(111, "cc-by")
  mock_inat(inat_search(p), inat_full(p))
  e <- example_data()
  cod <- e$dat[e$dat$predator_species_common_name == "Atlantic cod", ]
  prep <- suppressMessages(dv_prepare(
    cod, example_spec(predator_latin = "predator_species_latin_name"),
    taxonomy = "table", lineage = e$lin, verbose = FALSE))
  out <- file.path(dir, "dash.html")
  dv_build_html(prep, output = out, photo_source = "inaturalist",
                image_dir = dir, self_contained = FALSE)
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "Photo: Jane Doe, CC BY, via iNaturalist", fixed = TRUE)
  expect_match(html, "https://www.inaturalist.org/photos/111", fixed = TRUE)
})

test_that("sources are tried in order: iNaturalist first, then Wikimedia", {
  dir <- withr::local_tempdir()
  arr <- photo(1, NULL)                       # iNaturalist has no usable photo
  thumb <- "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Gadus_morhua.jpg/320px-Gadus_morhua.jpg"
  local_mocked_bindings(
    .dv_get_json = function(url) {
      if (grepl("/v1/taxa\\?", url)) inat_search(arr)
      else if (grepl("/v1/taxa/8336$", url)) inat_full(arr)
      else if (grepl("wikipedia.org/api", url))
        list(extract = "Wikipedia text.", thumbnail = list(source = thumb))
      else if (grepl("commons.wikimedia.org", url))
        list(query = list(pages = list(list(imageinfo = list(list(
          thumburl = thumb,
          descriptionurl = "https://commons.wikimedia.org/wiki/File:Gadus_morhua.jpg",
          extmetadata = list(Artist = list(value = "<a href='x'>Hans Hillewaert</a>"),
                             LicenseShortName = list(value = "CC BY-SA 4.0"))))))))
      else NULL
    },
    .dv_download = function(src, dest) { writeBin(as.raw(1:4), dest); TRUE })

  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir,
                              photo_source = c("inaturalist", "wikipedia"))
  expect_equal(a$source, "wikimedia")
  expect_equal(a$author, "Hans Hillewaert")
  expect_equal(a$credit, "Photo: Hans Hillewaert, CC BY-SA 4.0, via Wikimedia Commons")
  expect_true(file.exists(a$path))
  # the description came from the first source that had one (iNaturalist)
  expect_match(a$desc_credit, "via iNaturalist")
})

test_that("\"none\" cannot be combined, and the default stays offline", {
  expect_error(dv_species_card_assets("Atlantic cod",
                                      photo_source = c("none", "inaturalist")),
               "cannot be combined")
  dir <- withr::local_tempdir()
  calls <- mock_inat(NULL, NULL)
  a <- dv_species_card_assets("Atlantic cod", "Gadus morhua", image_dir = dir)
  expect_length(calls$urls, 0)
  expect_null(a$path)
})
