# Offline WoRMS: per-item fake functions turned into the vectorised worrms
# calls DietView makes, with the behaviour of worrms 0.4:
# - wm_record(ids): one row per ID, an NA row for an unknown ID, "(204)" error
#   when no ID is known;
# - wm_classification_(id = ids): rows with an `id` column; a failed ID gives
#   a warning (its message ends with the ID) and is left out;
# - wm_records_names() / wm_records_taxamatch(names): one data.frame per name,
#   empty for no match, "(204)" error when no name matches.
# A non-204 error of a per-item function fails the whole request, as a timeout
# fails a whole batch request. .dv_sleep() is mocked so retries do not wait.

is_204 <- function(e) grepl("(204)", conditionMessage(e), fixed = TRUE)

worms_vectorised <- function(record = NULL, classification = NULL,
                             names = NULL, taxamatch = NULL) {
  out <- list()
  if (!is.null(record)) out$wm_record <- function(id, ...) {
    rows <- lapply(id, function(i) tryCatch(as.data.frame(record(i)),
                                            error = function(e) if (is_204(e)) NULL else stop(e)))
    if (all(vapply(rows, is.null, logical(1))))
      stop("(204) No Content - AphiaRecordsByAphiaIDs")
    dplyr::bind_rows(lapply(rows, function(r) if (is.null(r)) data.frame(AphiaID = NA_integer_) else r))
  }
  if (!is.null(classification)) out$wm_classification_ <- function(id = NULL, name = NULL, ...) {
    rows <- lapply(id, function(i) tryCatch(
      cbind(id = as.character(i), as.data.frame(classification(i)), stringsAsFactors = FALSE),
      error = function(e) {
        msg <- conditionMessage(e)
        if (is_204(e) && !grepl(paste0(i, "$"), msg)) msg <- paste0(msg, " - ", i)
        warning(msg, call. = FALSE)
        NULL
      }))
    dplyr::bind_rows(rows)
  }
  vec_names <- function(f, what) function(name, marine_only = TRUE, ...) {
    res <- lapply(name, function(n) tryCatch({
      x <- f(n, marine_only = marine_only)
      if (is.data.frame(x)) x else x[[1]]
    }, error = function(e) if (is_204(e)) data.frame() else stop(e)))
    if (all(vapply(res, NROW, integer(1)) == 0L)) stop("(204) No Content - ", what)
    res
  }
  if (!is.null(names)) out$wm_records_names <- vec_names(names, "AphiaRecordsByNames")
  if (!is.null(taxamatch)) out$wm_records_taxamatch <- vec_names(taxamatch, "AphiaRecordsByMatchNames")
  out
}

local_worms <- function(..., .env = parent.frame()) {
  do.call(testthat::local_mocked_bindings,
          c(worms_vectorised(...), list(.package = "worrms", .env = .env)))
  testthat::local_mocked_bindings(.dv_sleep = function(seconds) invisible(NULL),
                                  .package = "DietView", .env = .env)
}
