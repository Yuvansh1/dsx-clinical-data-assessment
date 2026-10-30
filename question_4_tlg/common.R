source("scripts/common.R")
library(tidyr)
library(gtsummary)
library(ggplot2)

get_tlg_data <- function() {
  population <- pharmaverseadam::adsl |>
    filter(SAFFL == "Y", !is.na(ACTARM), nzchar(trimws(ACTARM))) |>
    select(USUBJID, ACTARM)
  stopifnot(!anyDuplicated(population$USUBJID))
  events <- pharmaverseadam::adae |> filter(TRTEMFL == "Y") |>
    select(-any_of("ACTARM")) |> inner_join(population, by = "USUBJID") |>
    mutate(AETERM = coalesce(na_if(trimws(AETERM), ""), "Not reported"),
           AESOC = coalesce(na_if(trimws(AESOC), ""), "Not reported"))
  list(population = population, events = events)
}
save_table <- function(data, filename, title, note) {
  data |> as_gtsummary() |> as_gt() |>
    gt::tab_header(title = title) |> gt::tab_source_note(note) |>
    gt::gtsave(file.path("outputs", filename))
}
