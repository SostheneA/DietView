#' Check a lineage for spelling variants and inconsistent placements
#'
#' An offline check of the lineage attached to the prey, run before any
#' figure is made. It flags two problems that split one taxon into several
#' nodes of the tree, and so inflate the number of taxa and of threshold
#' categories:
#' \itemize{
#'   \item \strong{near_duplicate}: two different labels at the same rank under
#'     the same parent whose spellings differ by at most `max_dist` edits
#'     (and by at most 10% of the length of the longer label). These are often
#'     an unaccepted spelling kept alongside the accepted name, e.g. a lineage
#'     frozen from an identifier that was not followed to its accepted record.
#'   \item \strong{multi_parent}: one label placed under more than one parent at
#'     the same rank, which gives that taxon two separate wedges.
#' }
#' It also flags \strong{genus_mismatch}: a binomial at the finest rank whose
#' first word differs from the genus.
#'
#' The check proposes; it does not repair. Correct the lineage table (or the
#' matching against WoRMS with [dv_prepare()]`(taxonomy = "worms")`, which
#' follows unaccepted AphiaIDs to their accepted record) and archive the
#' corrected table with the results.
#'
#' @param x A lineage data.frame (one row per prey key) or a `dietview_prep`
#'   from [dv_prepare()]. With a `dietview_prep`, the number of records
#'   carrying each flagged label is reported.
#' @param ranks Rank columns, coarse to fine. Defaults to the ranks of the
#'   `dietview_prep`, or to kingdom..species for a lineage table.
#' @param max_dist Largest edit distance (see [utils::adist()]) at which two
#'   labels are flagged as near duplicates.
#' @return A data.frame with one row per flag: `check`, `rank`, `parent`,
#'   `label`, `variant` (the other spelling or the other parent), `distance`
#'   and `n_records` (`NA` for a lineage table). Zero rows when nothing is
#'   flagged.
#' @examples
#' chk <- dv_lineage_check(ices_lineage)
#' chk[, c("check", "rank", "label", "variant")]
#' @export
dv_lineage_check <- function(x, ranks = NULL, max_dist = 2L) {
  if (inherits(x, "dietview_prep")) {
    if (is.null(ranks)) ranks <- x$ranks
    d <- x$data
    counted <- TRUE
  } else {
    d <- as.data.frame(x)
    if (is.null(ranks)) ranks <- c("kingdom", "phylum", "class", "order",
                                   "family", "genus", "species")
    counted <- FALSE
  }
  miss <- setdiff(ranks, names(d))
  if (length(miss)) stop("Rank column(s) absent: ", paste(miss, collapse = ", "),
                         call. = FALSE)
  lab <- function(r) { v <- trimws(as.character(d[[r]])); v[v %in% c("", "NA")] <- NA; v }
  L <- vapply(ranks, lab, character(nrow(d)))
  if (is.null(dim(L))) L <- matrix(L, nrow = nrow(d), dimnames = list(NULL, ranks))
  n_of <- function(j, label) if (counted) sum(L[, j] %in% label) else NA_integer_

  out <- list()
  push <- function(...) out[[length(out) + 1L]] <<- data.frame(..., stringsAsFactors = FALSE)
  for (j in seq_along(ranks)) {
    # nearest named ancestor, so a missing intermediate rank does not break the check
    par <- rep(NA_character_, nrow(L))
    for (k in seq_len(j - 1L)) par <- ifelse(!is.na(L[, k]), L[, k], par)
    ok <- !is.na(L[, j])
    pairs <- unique(data.frame(parent = par[ok], label = L[ok, j], stringsAsFactors = FALSE))

    dup <- unique(pairs$label[duplicated(pairs$label)])
    for (l in dup) {
      ps <- pairs$parent[pairs$label == l]
      ps[is.na(ps)] <- "(none)"
      ps <- sort(ps)
      push(check = "multi_parent", rank = ranks[j], parent = ps[1], label = l,
           variant = paste(ps[-1], collapse = " | "), distance = NA_integer_,
           n_records = n_of(j, l))
    }

    for (p in unique(pairs$parent)) {
      l <- sort(unique(pairs$label[pairs$parent %in% p]))
      if (length(l) < 2L) next
      dm <- utils::adist(l)
      lim <- pmin(max_dist, pmax(1L, floor(0.1 * outer(nchar(l), nchar(l), pmax))))
      hit <- which(upper.tri(dm) & dm > 0 & dm <= lim, arr.ind = TRUE)
      for (h in seq_len(nrow(hit))) {
        a <- l[hit[h, 1]]; b <- l[hit[h, 2]]
        push(check = "near_duplicate", rank = ranks[j], parent = p, label = a,
             variant = b, distance = as.integer(dm[hit[h, 1], hit[h, 2]]),
             n_records = n_of(j, c(a, b)))
      }
    }
  }

  gi <- match("genus", ranks); si <- length(ranks)
  if (!is.na(gi) && si > gi) {
    g <- L[, gi]; s <- L[, si]
    bad <- !is.na(g) & !is.na(s) & grepl(" ", s) & sub(" .*", "", s) != g
    for (l in unique(s[bad])) {
      push(check = "genus_mismatch", rank = ranks[si], parent = g[bad & s == l][1],
           label = l, variant = sub(" .*", "", l), distance = NA_integer_,
           n_records = n_of(si, l))
    }
  }

  res <- if (length(out)) do.call(rbind, out) else
    data.frame(check = character(0), rank = character(0), parent = character(0),
               label = character(0), variant = character(0), distance = integer(0),
               n_records = integer(0), stringsAsFactors = FALSE)
  rownames(res) <- NULL
  res
}
