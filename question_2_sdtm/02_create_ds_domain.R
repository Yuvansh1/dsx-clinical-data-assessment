source("scripts/common.R")
library(sdtm.oak)

create_ds <- function(raw = pharmaverseraw::ds_raw, dm = pharmaversesdtm::dm) {
  study_ct <- data.frame(
    codelist_code = "C66727",
    term_code = c("C41331", "C25250", "C28554", "C48226", "C48227", "C48250",
                  "C142185", "C49628", "C49632", "C49634", NA_character_),
    term_value = c("ADVERSE EVENT", "COMPLETED", "DEATH", "LACK OF EFFICACY",
                   "LOST TO FOLLOW-UP", "PHYSICIAN DECISION", "PROTOCOL VIOLATION",
                   "SCREEN FAILURE", "STUDY TERMINATED BY SPONSOR",
                   "WITHDRAWAL BY SUBJECT", "RANDOMIZED"),
    collected_value = c("Adverse Event", "Complete", "Dead", "Lack of Efficacy",
                        "Lost To Follow-Up", "Physician Decision", "Protocol Violation",
                        "Trial Screen Failure", "Study Terminated By Sponsor",
                        "Withdrawal by Subject", "Randomized"),
    term_preferred_term = c("AE", "Completed", "Died", NA, NA, NA, "Violation",
                            "Failure to Meet Inclusion/Exclusion Criteria", NA, "Dropout", NA),
    term_synonyms = c("ADVERSE EVENT", "COMPLETE", "Death", NA, NA, NA, NA, NA, NA,
                      "Discontinued Participation", NA)
  )
  raw <- raw |> generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ds_raw")
  # Canonicalize case and known spelling variants before controlled-term mapping.
  lookup <- setNames(study_ct$collected_value, toupper(study_ct$collected_value))
  lookup <- c(lookup, "COMPLETED" = "Complete", "DEATH" = "Dead",
              "SCREEN FAILURE" = "Trial Screen Failure")
  raw$reason <- unname(lookup[toupper(trimws(raw$IT.DSDECOD))])
  raw$other <- !is.na(raw$OTHERSP) & nzchar(trimws(raw$OTHERSP))
  if (any(is.na(raw$reason) & !raw$other)) stop("Unmapped disposition reason")
  raw$reported <- ifelse(raw$other, raw$OTHERSP, raw$IT.DSTERM)
  ds <- assign_no_ct(raw_dat = raw, raw_var = "reported", tgt_var = "DSTERM") |>
    assign_ct(raw_dat = raw, raw_var = "reason", tgt_var = "DSDECOD",
              ct_spec = study_ct, ct_clst = "C66727") |>
    assign_datetime(raw_dat = raw, raw_var = "IT.DSSTDAT", tgt_var = "DSSTDTC",
                    raw_fmt = "m-d-y") |>
    assign_datetime(raw_dat = raw, raw_var = c("DSDTCOL", "DSTMCOL"),
                    tgt_var = "DSDTC", raw_fmt = c("m-d-y", "H:M"))
  # Join by stable record identifiers, never by implicit row position.
  ds <- ds |> left_join(raw |> select(oak_id, STUDY, PATNUM, other, OTHERSP,
                                      IT.DSDECOD, INSTANCE), by = "oak_id")
  visits <- pharmaversesdtm::sv |> distinct(VISIT, VISITNUM)
  stopifnot(!anyDuplicated(visits$VISIT))
  ds <- ds |> mutate(VISIT = toupper(INSTANCE)) |> left_join(visits, by = "VISIT")
  if (anyNA(ds$VISITNUM)) stop("Unmapped raw visit name")
  ds <- ds |> mutate(
    STUDYID = STUDY, DOMAIN = "DS", USUBJID = paste0("01-", PATNUM),
    DSDECOD = if_else(other, OTHERSP, DSDECOD),
    DSCAT = case_when(other ~ "OTHER EVENT",
                     toupper(IT.DSDECOD) == "RANDOMIZED" ~ "PROTOCOL MILESTONE",
                     TRUE ~ "DISPOSITION EVENT"),
    DSTERM = toupper(DSTERM), DSDECOD = toupper(DSDECOD),
    DSDTC = as.character(DSDTC), DSSTDTC = as.character(DSSTDTC)
  )
  stopifnot(!anyDuplicated(dm$USUBJID), all(ds$USUBJID %in% dm$USUBJID))
  ds <- ds |> left_join(dm |> select(USUBJID, RFSTDTC), by = "USUBJID") |>
    mutate(event_date = complete_date(DSSTDTC), reference_date = complete_date(RFSTDTC),
           DSSTDY = as.integer(event_date - reference_date) +
             if_else(event_date >= reference_date, 1L, 0L)) |>
    arrange(STUDYID, USUBJID, DSSTDTC, DSDTC, DSTERM, oak_id) |>
    group_by(STUDYID, USUBJID) |> mutate(DSSEQ = row_number()) |> ungroup() |>
    select(STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
           VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY)
  stopifnot(nrow(ds) == nrow(raw), !anyDuplicated(ds[c("USUBJID", "DSSEQ")]))
  ds
}
ds <- create_ds()
write_dataset(ds, "ds")
