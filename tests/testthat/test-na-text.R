# Unidentified ("NA") wedges carry no text; label and hover text are unchanged.

test_that(".dv_sb_prep() blanks the text of NA nodes only", {
  prep <- example_prep()
  tree <- dv_tree(prep)
  na <- tree$label == "NA"
  expect_true(any(na))
  for (mode in c("occurrence", "weight", "count")) {
    pp <- DietView:::.dv_sb_prep(tree, mode)
    expect_equal(pp$tree$text[na], rep("", sum(na)))
    expect_equal(pp$tree$text[!na], tree$label[!na])
    expect_true(all(grepl("Not identified at this rank", pp$tree$hovertext[na], fixed = TRUE)))
    # labels, ids and values unchanged
    expect_equal(pp$tree$label, tree$label)
    expect_equal(pp$tree$id, tree$id)
    expect_equal(pp$tree$value_occ, tree$value_occ)
    expect_equal(pp$tree$value_w, tree$value_w)
  }
  # gap nodes keep their text
  expect_equal(DietView:::.dv_wedge_text(c("Polychaeta (no order)", "(no class)", "NA", "Gadidae")),
               c("Polychaeta (no order)", "(no class)", "", "Gadidae"))
})

test_that("dv_sunburst() draws text, not labels, and hovers on hovertext", {
  prep <- example_prep()
  tree <- dv_tree(prep)
  tr <- plotly::plotly_build(dv_sunburst(tree))$x$data[[1]]
  na <- tr$labels == "NA"
  expect_true(any(na))
  expect_equal(unique(as.character(tr$textinfo)), "text")
  expect_equal(unique(as.character(tr$hovertemplate)), "%{hovertext}<extra></extra>")
  expect_true(all(tr$text[na] == ""))
  expect_equal(tr$text[!na], as.character(tr$labels[!na]))
  expect_true(all(grepl("Not identified at this rank", tr$hovertext[na], fixed = TRUE)))
  expect_equal(as.character(tr$ids), tree$id)
})

test_that("the dashboard JSON blanks the text of NA nodes", {
  prep <- example_prep()
  out <- tempfile(fileext = ".html"); on.exit(unlink(out), add = TRUE)
  dv_build_html(prep, output = out, strata = character(0))
  x <- dash_data(out)
  n <- x$data$nodes
  lab <- unlist(n$label); txt <- unlist(n$text); tax <- unlist(n$taxon)
  na <- lab == "NA"
  expect_true(any(na))
  expect_equal(txt[na], rep("", sum(na)))
  expect_equal(txt[!na], lab[!na])
  expect_equal(unique(tax[na]), "Not identified at this rank")
  expect_match(x$html, "textinfo:'text'", fixed = TRUE)
  expect_match(x$html, "t.text.push(N.text[k])", fixed = TRUE)
  expect_match(x$html, "hovertemplate:'%{hovertext}<extra></extra>'", fixed = TRUE)
})
