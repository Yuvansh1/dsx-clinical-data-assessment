source("scripts/common.R")
library(admiral)

create_adsl <- function(dm = pharmaversesdtm::dm, vs = pharmaversesdtm::vs,
                        ex = pharmaversesdtm::ex, ds = pharmaversesdtm::ds,
                        ae = pharmaversesdtm::ae) {
  stopifnot(!anyDuplicated(dm$USUBJID))
  adsl <- dm |> mutate(
    AGEGR9 = case_when(is.na(AGE) ~ NA_character_, AGE < 18 ~ "<18",
                       AGE <= 50 ~ "18 - 50", TRUE ~ ">50"),
    AGEGR9N = match(AGEGR9, c("<18", "18 - 50", ">50")),
    ITTFL = if_else(!is.na(ARM) & nzchar(trimws(ARM)), "Y", "N")
  )
  valid_ex <- ex |> filter(EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT))))
  # Complete dates only; impute missing time, suppress seconds-only flags.
  starts <- valid_ex |>
    derive_vars_dtm(new_vars_prefix = "TRTS", dtc = EXSTDTC,
                    highest_imputation = "h", time_imputation = "first",
                    flag_imputation = "time", ignore_seconds_flag = FALSE) |>
    mutate(TRTSTMF = na_if(TRTSTMF, "S")) |>
    filter(!is.na(TRTSDTM)) |> arrange(USUBJID, TRTSDTM, EXSEQ) |>
    group_by(USUBJID) |> slice_head(n = 1) |> ungroup() |>
    select(USUBJID, TRTSDTM, TRTSTMF)
  # End date represents last administration in an interval. When unavailable,
  # a complete start date is still evidence of administration on that day.
  ends <- valid_ex |>
    mutate(end_dtc = if_else(!is.na(complete_date(EXENDTC)), EXENDTC, EXSTDTC)) |>
    derive_vars_dtm(new_vars_prefix = "TRTE", dtc = end_dtc,
                    highest_imputation = "h", time_imputation = "last",
                    flag_imputation = "time", ignore_seconds_flag = FALSE) |>
    mutate(TRTETMF = na_if(TRTETMF, "S")) |>
    filter(!is.na(TRTEDTM)) |> arrange(USUBJID, desc(TRTEDTM), EXSEQ) |>
    group_by(USUBJID) |> slice_head(n = 1) |> ungroup() |>
    select(USUBJID, TRTEDTM, TRTETMF)
  abnormal <- vs |> filter(VSTESTCD == "SYSBP", VSSTRESU == "mmHg",
                            VSSTRESN < 100 | VSSTRESN >= 140) |>
    distinct(USUBJID) |> mutate(ABNSBPFL = "Y")
  cardiac <- ae |> filter(toupper(AESOC) == "CARDIAC DISORDERS") |>
    distinct(USUBJID) |> mutate(CARPOPFL = "Y")
  alive <- bind_rows(
    vs |> filter(!is.na(VSSTRESN) | (!is.na(VSSTRESC) & nzchar(trimws(VSSTRESC)))) |>
      transmute(USUBJID, date = complete_date(VSDTC)),
    ae |> transmute(USUBJID, date = complete_date(AESTDTC)),
    ds |> transmute(USUBJID, date = complete_date(DSSTDTC)),
    ends |> transmute(USUBJID, date = as.Date(TRTEDTM, tz = "UTC"))
  ) |> filter(!is.na(date)) |> group_by(USUBJID) |>
    summarise(LSTALVDT = max(date), .groups = "drop")
  adsl <- adsl |> left_join(starts, by = "USUBJID") |> left_join(ends, by = "USUBJID") |>
    left_join(abnormal, by = "USUBJID") |> left_join(cardiac, by = "USUBJID") |>
    left_join(alive, by = "USUBJID") |> mutate(ABNSBPFL = coalesce(ABNSBPFL, "N"))
  stopifnot(nrow(adsl) == nrow(dm), !anyDuplicated(adsl$USUBJID))
  adsl
}
adsl <- create_adsl()
write_dataset(adsl, "adsl")
