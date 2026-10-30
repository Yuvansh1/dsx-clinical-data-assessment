if (dir.exists(".Rlibrary")) .libPaths(c(normalizePath(".Rlibrary"), .libPaths()))
dir.create("outputs", showWarnings = FALSE)
dir.create("data", showWarnings = FALSE)
options(dplyr.summarise.inform = FALSE)
Sys.setenv(TZ = "UTC")
library(dplyr)
complete_date <- function(x) {
  x <- as.character(x)
  ok <- !is.na(x) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}($|T)", x)
  as.Date(ifelse(ok, substr(x, 1, 10), NA_character_), format = "%Y-%m-%d")
}
write_dataset <- function(x, name) {
  saveRDS(x, file.path("outputs", paste0(name, ".rds")))
  write.csv(x, file.path("outputs", paste0(name, ".csv")), row.names = FALSE, na = "")
}
