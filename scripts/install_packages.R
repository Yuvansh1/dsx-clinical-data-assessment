dir.create(".Rlibrary", showWarnings = FALSE)
.libPaths(c(normalizePath(".Rlibrary"), .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
packages <- c("admiral", "sdtm.oak", "pharmaverseraw", "pharmaversesdtm",
              "pharmaverseadam", "dplyr", "tidyr", "ggplot2", "gtsummary",
              "gt", "testthat", "roxygen2")
missing <- setdiff(packages, rownames(installed.packages()))
if (length(missing)) install.packages(missing)
stopifnot(all(packages %in% rownames(installed.packages())))
