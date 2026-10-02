# Rule-based harm-type classifier over the ementa (validated by annotation, D5)

load_harm_types <- function(path = "config/harm_types.yml") yaml::read_yaml(path)

classify_harm <- function(ementa, types = load_harm_types()) {
  if (is.null(ementa) || length(ementa) == 0 || is.na(ementa)) return("other")
  # stringi lower-casing is locale-independent (base tolower() leaves "Ó" untouched
  # under a C/POSIX locale, which silently broke accented patterns).
  x <- stringi::stri_trans_tolower(ementa)
  for (t in types) {
    if (length(t$patterns) == 0) next
    if (any(vapply(t$patterns, function(p) stringi::stri_detect_regex(x, p), logical(1)))) return(t$id)
  }
  "other"
}

classify_harm_vec <- function(ementas, types = load_harm_types()) {
  vapply(ementas, classify_harm, character(1), types = types, USE.NAMES = FALSE)
}
