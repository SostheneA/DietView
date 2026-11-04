#' Split a lineage string into rank columns
#'
#' Metabarcoding pipelines (QIIME 2, DADA2, mothur, SILVA, Greengenes, MIDORI,
#' BOLD, a BLAST against GenBank) report each sequence's taxonomy as one
#' string, such as `"k__Animalia; p__Arthropoda; c__Copepoda; g__Calanus;
#' s__finmarchicus"`. `dv_parse_lineage()` splits that string into one column
#' per rank, so the data can be prepared with `dv_prepare(taxonomy =
#' "columns")`, keeping the reference taxonomy the sequences were assigned
#' with (NCBI, SILVA, BOLD ...), or only the deepest name can be passed on to
#' WoRMS or GBIF.
#'
#' Two layouts are read:
#' \itemize{
#'   \item **prefixed** - each field starts with a rank code (`k__`, `d__`,
#'     `p__`, `c__`, `o__`, `f__`, `g__`, `s__`; also `k:`/`p:` and
#'     `kingdom:`); fields are placed by their code, so missing ranks are
#'     allowed. `d__` (domain) is ignored unless `"domain"` is a rank;
#'   \item **positional** - plain names in rank order (`"Animalia;Arthropoda;
#'     ..."`); the i-th field goes to the i-th rank of `ranks`.
#' }
#' `format = "auto"` uses prefixed when most strings carry rank codes. For
#' positional strings, give `ranks` in the order of the fields: MIDORI and
#' NCBI lineages start with a superkingdom, not a kingdom, so use e.g.
#' `ranks = c("domain", "phylum", "class", "order", "family", "genus",
#' "species")` and the same `ranks` in [dv_spec()].
#' Placeholders such as an empty field, `"NA"`, `"unassigned"`,
#' `"unclassified"`, `"uncultured"`, `"unidentified"`, `"unknown"`,
#' `"metagenome"` or a species written `"Genus sp."` become `NA`, so the
#' record is shown as unidentified at that rank. Trailing NCBI tax IDs
#' (`"Calanus_6836"`) and underscores (`"Calanus_finmarchicus"`) are cleaned,
#' and a species given as an epithet only (`s__finmarchicus`) is completed with
#' its genus.
#'
#' @param data A data.frame.
#' @param col Name of the column holding the lineage string.
#' @param ranks Ranks to create, coarse to fine (default the seven flagship
#'   ranks). For positional strings they must follow the order of the fields.
#' @param sep Field separator (default `";"`).
#' @param format `"auto"` (default), `"prefixed"` or `"positional"`.
#' @param name_col If not `NULL` (default `"prey_name"`), a column with the
#'   deepest identified name is added (or overwritten), ready for
#'   `dv_spec(prey_name = )`.
#' @param placeholders Lower-case values treated as "not identified".
#' @return `data` with one column per rank (and `name_col`).
#' @seealso [dv_from_wide()] to reshape a sample-by-taxon table first.
#' @examples
#' x <- data.frame(asv = c("a1", "a2", "a3"), taxonomy = c(
#'   paste("k__Animalia; p__Arthropoda; c__Copepoda; o__Calanoida;",
#'         "f__Calanidae; g__Calanus; s__finmarchicus"),
#'   "k__Animalia; p__Chordata; c__Actinopteri; o__; f__; g__; s__",
#'   "Unassigned"))
#' dv_parse_lineage(x, "taxonomy")
#' # plain names in rank order, as in many BLAST or BOLD outputs
#' y <- data.frame(lin = paste("Animalia;Arthropoda;Malacostraca;Euphausiacea",
#'                             "Euphausiidae;Meganyctiphanes",
#'                             "Meganyctiphanes norvegica", sep = ";"))
#' dv_parse_lineage(y, "lin")
#' @export
dv_parse_lineage <- function(data, col,
                             ranks = c("kingdom", "phylum", "class", "order",
                                       "family", "genus", "species"),
                             sep = ";",
                             format = c("auto", "prefixed", "positional"),
                             name_col = "prey_name",
                             placeholders = c("", "na", "nan", "none", "null",
                                              "unassigned", "unclassified",
                                              "uncultured", "unidentified",
                                              "unknown", "metagenome",
                                              "environmental sample")) {
  format <- match.arg(format)
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (!col %in% names(data)) stop("Column `", col, "` is not in `data`.", call. = FALSE)
  s <- as.character(data[[col]])
  fields <- lapply(strsplit(ifelse(is.na(s), "", s), sep, fixed = TRUE), trimws)

  code_re <- "^([A-Za-z]+)(__|:)(.*)$"
  if (format == "auto") {
    has_code <- vapply(fields, function(f) length(f) > 0 &&
                         mean(grepl(code_re, f)) >= 0.5, logical(1))
    format <- if (mean(has_code[nzchar(s) & !is.na(s)]) >= 0.5) "prefixed" else "positional"
  }
  codes <- c(d = "domain", domain = "domain", k = "kingdom", kingdom = "kingdom",
             p = "phylum", phylum = "phylum", c = "class", class = "class",
             o = "order", order = "order", f = "family", family = "family",
             g = "genus", genus = "genus", s = "species", species = "species")

  clean <- function(v) {
    v <- sub("_[0-9]+$", "", v)                    # MIDORI / NCBI "Calanus_6836"
    v <- trimws(gsub("_", " ", v))
    v <- gsub("\\s+", " ", v)
    v[tolower(v) %in% placeholders |
        grepl("^(uncultured|unidentified|unclassified|unknown)\\b", v, ignore.case = TRUE)] <- NA
    v
  }

  n <- length(s)
  out <- matrix(NA_character_, n, length(ranks), dimnames = list(NULL, ranks))
  for (i in seq_len(n)) {
    f <- fields[[i]]
    f <- f[nzchar(f) | format == "positional"]
    if (!length(f)) next
    if (format == "prefixed") {
      m <- regmatches(f, regexec(code_re, f))
      for (x in m) {
        if (length(x) < 4) next
        r <- codes[tolower(x[2])]
        if (!is.na(r) && r %in% ranks) out[i, r] <- x[4]
      }
    } else {
      k <- min(length(f), length(ranks))
      out[i, seq_len(k)] <- f[seq_len(k)]
    }
  }
  for (j in seq_along(ranks)) out[, j] <- clean(out[, j])

  if ("species" %in% ranks) {
    sp <- out[, "species"]
    # "Genus sp." / "Genus spp." / "Genus cf." are not species
    sp[grepl("\\s(sp|spp|cf|aff|nr)\\.?(\\s|$)", sp)] <- NA
    if ("genus" %in% ranks) {
      g <- out[, "genus"]
      epithet <- !is.na(sp) & !grepl(" ", sp) & !is.na(g) & grepl("^[a-z]", sp)
      sp[epithet] <- paste(g[epithet], sp[epithet])
    }
    out[, "species"] <- sp
  }

  for (r in ranks) data[[r]] <- out[, r]
  if (!is.null(name_col)) {
    deepest <- rep(NA_character_, n)
    for (r in ranks) deepest <- ifelse(!is.na(out[, r]), out[, r], deepest)
    data[[name_col]] <- deepest
  }
  data
}

#' Reshape a wide sample-by-taxon table into DietView's long format
#'
#' DNA metabarcoding (ASV/OTU tables), catch composition and many survey
#' tables come wide: one row per taxon and one column per sample, or the
#' reverse. `dv_from_wide()` turns them into the long table DietView expects,
#' one row per taxon in a sample, and joins the sample metadata (predator,
#' covariates) so the result goes straight into [dv_spec()] and
#' [dv_prepare()].
#'
#' Records with a zero or missing value are dropped (`drop_zero = TRUE`), as
#' a prey absent from a sample is not a prey record. With `collapse_by`, the
#' values of the rows that share a sample and the same `collapse_by` columns
#' (e.g. several ASVs assigned to the same species) are summed into one
#' record, so that shares of prey records and %FO count a taxon once per
#' sample.
#'
#' @param x A data.frame.
#' @param taxa_in `"rows"` (default; one row per taxon, one column per sample,
#'   the usual ASV/OTU table) or `"columns"` (one row per sample, one column
#'   per taxon).
#' @param id_cols Columns that are not counts: with `taxa_in = "rows"`, the
#'   columns describing the taxon (ASV id, lineage string, rank columns ...);
#'   with `taxa_in = "columns"`, the columns describing the sample. Every
#'   other column is read as counts.
#' @param sample_col Name of the sample column in the result (with
#'   `taxa_in = "columns"`, it must be one of `id_cols`). Use it as
#'   `dv_spec(stomach = )`.
#' @param value_col Name of the value column in the result (e.g. `"reads"`),
#'   for `dv_spec(weight = )` or `dv_spec(count = )`.
#' @param taxon_col With `taxa_in = "columns"`, the name of the column that
#'   receives the taxon names (the former column names).
#' @param meta Optional data.frame of sample metadata (predator, date, area,
#'   ...), joined by `sample_col`. A sample without metadata is kept, with a
#'   warning.
#' @param drop_zero Drop records whose value is 0 or missing (default `TRUE`).
#' @param collapse_by Optional columns defining one prey; rows sharing a
#'   sample and these columns are summed into one record.
#' @return A long data.frame: the taxon columns, `sample_col`, `value_col` and
#'   the metadata columns.
#' @seealso [dv_parse_lineage()] to split a lineage string into ranks.
#' @examples
#' # an ASV table: one row per ASV, one column per scat sample
#' asv <- data.frame(
#'   asv = c("a1", "a2", "a3"),
#'   taxonomy = c("k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
#'                "k__Animalia;p__Chordata;c__Actinopteri;o__Gadiformes;f__Gadidae;g__Gadus;s__morhua",
#'                "k__Animalia;p__Arthropoda;c__Malacostraca;o__Euphausiacea;f__;g__;s__"),
#'   S1 = c(120, 30, 0), S2 = c(0, 0, 400))
#' meta <- data.frame(sample = c("S1", "S2"), predator = "grey seal",
#'                    season = c("winter", "summer"))
#' long <- dv_from_wide(asv, id_cols = c("asv", "taxonomy"), meta = meta,
#'                      collapse_by = "taxonomy")
#' long <- dv_parse_lineage(long, "taxonomy")
#' spec <- dv_spec(predator = "predator", stomach = "sample",
#'                 prey_name = "prey_name", weight = "reads",
#'                 weight_type = "rra", covariates = "season")
#' prep <- dv_prepare(long, spec, taxonomy = "columns", verbose = FALSE)
#' dv_rank_table(dv_tree(prep), "Phylum")
#' @export
dv_from_wide <- function(x, taxa_in = c("rows", "columns"), id_cols,
                         sample_col = "sample", value_col = "reads",
                         taxon_col = "prey_name", meta = NULL,
                         drop_zero = TRUE, collapse_by = NULL) {
  taxa_in <- match.arg(taxa_in)
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  miss <- setdiff(id_cols, names(x))
  if (length(miss)) stop("`id_cols` not in `x`: ", paste(miss, collapse = ", "), call. = FALSE)
  if (taxa_in == "columns" && !sample_col %in% id_cols)
    stop("With taxa_in = 'columns', `sample_col` (`", sample_col,
         "`) must be one of `id_cols`.", call. = FALSE)
  val_cols <- setdiff(names(x), id_cols)
  if (!length(val_cols)) stop("No count columns left once `id_cols` are set aside.", call. = FALSE)
  bad <- val_cols[!vapply(x[val_cols], function(v)
    is.numeric(v) || all(is.na(suppressWarnings(as.numeric(v))) == is.na(v)), logical(1))]
  if (length(bad))
    stop("These columns are not counts (add them to `id_cols`?): ",
         paste(utils::head(bad, 5), collapse = ", "), call. = FALSE)

  key_name <- if (taxa_in == "rows") sample_col else taxon_col
  long <- do.call(rbind, lapply(val_cols, function(v) {
    d <- x[, id_cols, drop = FALSE]
    d[[key_name]] <- v
    d[[value_col]] <- suppressWarnings(as.numeric(x[[v]]))
    d
  }))
  if (drop_zero) long <- long[!is.na(long[[value_col]]) & long[[value_col]] != 0, , drop = FALSE]

  if (!is.null(collapse_by)) {
    miss <- setdiff(collapse_by, names(long))
    if (length(miss)) stop("`collapse_by` not in the data: ", paste(miss, collapse = ", "),
                           call. = FALSE)
    grp <- unique(c(sample_col, collapse_by))
    g <- interaction(long[grp], drop = TRUE, lex.order = TRUE)
    first <- !duplicated(g)
    tot <- tapply(long[[value_col]], g, sum, na.rm = TRUE)
    long <- long[first, c(grp, value_col), drop = FALSE]
    long[[value_col]] <- as.numeric(tot[as.character(g[first])])
  }

  if (!is.null(meta)) {
    meta <- as.data.frame(meta, stringsAsFactors = FALSE)
    if (!sample_col %in% names(meta))
      stop("`meta` must contain the sample column `", sample_col, "`.", call. = FALSE)
    if (anyDuplicated(meta[[sample_col]]))
      stop("`meta` must have one row per sample.", call. = FALSE)
    absent <- setdiff(unique(as.character(long[[sample_col]])), as.character(meta[[sample_col]]))
    if (length(absent))
      warning(length(absent), " sample(s) have no row in `meta` (e.g. ",
              paste(utils::head(absent, 3), collapse = ", "),
              "); their metadata are missing.", call. = FALSE)
    extra <- setdiff(names(meta), c(sample_col, names(long)))
    idx <- match(as.character(long[[sample_col]]), as.character(meta[[sample_col]]))
    for (m in extra) long[[m]] <- meta[[m]][idx]
  }
  rownames(long) <- NULL
  long
}
