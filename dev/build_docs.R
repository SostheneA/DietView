#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Build the DietView documentation: man/ + NAMESPACE, the pkgdown site, and the
# technical-reference PDF -- which is regenerated from the article itself, so
# the PDF can never drift from the web version.
#
#   Rscript dev/build_docs.R            # document + site + PDF
#   Rscript dev/build_docs.R --no-site  # only refresh the PDF
#
# The PDF is produced with pagedown::chrome_print(), i.e. headless Chrome. No
# LaTeX needed. The article is printed over a local server rooted at docs/,
# because the page loads shared assets from ../deps/ -- a server rooted at
# docs/articles/ cannot reach them and every dependency 404s.
# If a step is unavailable the site still builds and only the PDF is skipped.
# ---------------------------------------------------------------------------

args     <- commandArgs(trailingOnly = TRUE)
do_site  <- !("--no-site" %in% args)

ARTICLE  <- "docs/articles/technical-reference.html"
PDF_OUT  <- "docs/DietView-technical-reference.pdf"

need <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE))
    stop("Package '", pkg, "' is required. install.packages('", pkg, "')",
         call. = FALSE)
}

# 1. roxygen -> man/ + NAMESPACE ------------------------------------------
need("devtools")
message("== documenting ==")
devtools::document()

# 2. pkgdown site ----------------------------------------------------------
if (do_site) {
  need("pkgdown")
  message("== building site ==")
  pkgdown::build_site(preview = FALSE)
}

# 3. technical reference -> PDF (always regenerated from the article) -------
build_pdf <- function() {
  if (!file.exists(ARTICLE)) {
    message("!! ", ARTICLE, " not found -- run without --no-site first.")
    return(invisible(FALSE))
  }
  for (p in c("pagedown", "servr")) {
    if (!requireNamespace(p, quietly = TRUE)) {
      message("!! '", p, "' not installed; skipping the PDF.\n",
              "   install.packages('", p, "')")
      return(invisible(FALSE))
    }
  }

  message("== rendering ", PDF_OUT, " ==")

  # Serve the SITE ROOT, not the article's folder. The article references
  # shared assets as ../deps/... ; a server rooted at docs/articles/ cannot
  # resolve above its own root and returns 404 for every dependency.
  port <- servr::random_port()
  srv  <- servr::httd(dir = "docs", port = port, browser = FALSE, daemon = TRUE)
  on.exit({
    if (is.list(srv) && is.function(srv$stop_server)) {
      try(srv$stop_server(), silent = TRUE)
    } else {
      try(servr::daemon_stop(), silent = TRUE)
    }
  }, add = TRUE)

  url <- sprintf("http://127.0.0.1:%d/%s", port,
                 sub("^docs/", "", ARTICLE))

  ok <- tryCatch({
    pagedown::chrome_print(url, output = PDF_OUT, timeout = 1200)
    TRUE
  }, error = function(e) {
    message("!! PDF step failed: ", conditionMessage(e), "\n",
            "   The site itself built fine; only the PDF was skipped.\n",
            "   Check that Chrome/Chromium is installed and visible to\n",
            "   pagedown::find_chrome().")
    FALSE
  })

  if (isTRUE(ok)) message("   wrote ", PDF_OUT)
  invisible(ok)
}
build_pdf()

message("== done ==")
if (do_site) message("Preview with: pkgdown::preview_site()")
