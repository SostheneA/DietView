# Reads a dashboard file: its HTML and the parsed JSON data block.
dash_data <- function(path) {
  html <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  json <- sub(".*<script type=\"application/json\" id=\"dv-data\">(.*?)</script>.*", "\\1", html)
  list(html = html, data = jsonlite::fromJSON(json, simplifyVector = FALSE))
}
