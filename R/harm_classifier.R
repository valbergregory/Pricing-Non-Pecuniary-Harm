# Rule-based harm-type classifier over the ementa (validated by annotation, D5)

load_harm_types <- function(path = "config/harm_types.yml") yaml::read_yaml(path)

classify_harm <- function(ementa, types = load_harm_types()) {
  if (is.null(ementa) || is.na(ementa)) return("other")
  x <- tolower(ementa)
  for (t in types) {
    if (length(t$patterns) == 0) next
    if (any(vapply(t$patterns, function(p) stringi::stri_detect_regex(x, p), logical(1)))) return(t$id)
  }
  "other"
}

classify_harm_vec <- function(ementas, types = load_harm_types()) {
  vapply(ementas, classify_harm, character(1), types = types, USE.NAMES = FALSE)
}
