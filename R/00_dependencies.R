# Declares packages used in phase 1 (estimation) so renv::snapshot() pins them even
# before the modelling scripts exist. Never sourced for side effects.
phase1_dependencies <- function() {
  c("lme4", "quantreg", "fixest", "sandwich", "boot", "modelsummary", "ggplot2",
    "targets", "tarchetypes", "knitr", "rmarkdown")
}
if (FALSE) {
  requireNamespace("lme4"); requireNamespace("quantreg"); requireNamespace("fixest")
  requireNamespace("sandwich"); requireNamespace("boot"); requireNamespace("modelsummary")
  requireNamespace("ggplot2"); requireNamespace("targets"); requireNamespace("tarchetypes")
  requireNamespace("knitr"); requireNamespace("rmarkdown")
}
