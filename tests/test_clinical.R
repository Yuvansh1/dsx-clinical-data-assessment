source("scripts/common.R")
library(testthat)
source("question_3_adam/create_adsl.R")

test_that("ADSL boundaries, dose rules, time flags and last-alive dates are correct", {
  dm <- tibble(USUBJID = paste0("S", 1:5), AGE = c(17, 18, 50, 51, NA),
               ARM = c("Active", "Placebo", "", NA, "Active"))
  ex <- tibble(USUBJID = c("S1", "S1", "S2", "S3", "S4", "S5"),
               EXSEQ = c(1, 2, 1, 1, 1, 1), EXDOSE = c(0, 10, 0, 1, 1, 1),
               EXTRT = c("ACTIVE", "ACTIVE", "PLACEBO", "ACTIVE", "ACTIVE", "ACTIVE"),
               EXSTDTC = c("2020-01-01", "2020-02-01", "2020-02-01T12",
                            "2020-02-01T12:34", "2020-02", "2020-02-01T12:34:56"),
               EXENDTC = c("2020-01-02", "2020-02-03", "2020-02-02",
                            "2020-02-04", "2020-02", NA))
  vs <- tibble(USUBJID = c("S1", "S2", "S3", "S4", "S5"),
               VSTESTCD = "SYSBP", VSSTRESU = c("mmHg", "mmHg", "mmHg", "mmHg", "kPa"),
               VSSTRESN = c(99, 100, 139, 140, 150), VSSTRESC = as.character(VSSTRESN),
               VSDTC = c("2020-03-01", "2020-03", "2020-03-02", NA, NA))
  ae <- tibble(USUBJID = c("S1", "S2"), AESOC = c("Cardiac Disorders", "SKIN DISORDERS"),
               AESTDTC = c("2020-03-04", "2020-03"))
  ds <- tibble(USUBJID = "S1", DSSTDTC = "2020-03-05")
  result <- create_adsl(dm, vs, ex, ds, ae)
  expect_equal(result$AGEGR9N, c(1L, 2L, 2L, 3L, NA_integer_))
  expect_equal(result$AGEGR9, c("<18", "18 - 50", "18 - 50", ">50", NA))
  expect_equal(result$ITTFL, c("Y", "Y", "N", "N", "Y"))
  expect_equal(result$ABNSBPFL, c("Y", "N", "N", "Y", "N"))
  expect_equal(result$CARPOPFL, c("Y", NA, NA, NA, NA))
  expect_equal(format(result$TRTSDTM[1], tz = "UTC"), "2020-02-01")
  expect_equal(result$TRTSTMF, c("H", "M", NA, NA, NA))
  expect_true(is.na(result$TRTSDTM[4]))
  expect_equal(as.character(result$LSTALVDT),
               c("2020-03-05", "2020-02-02", "2020-03-02", NA, "2020-02-01"))
})

source("question_2_sdtm/02_create_ds_domain.R")
test_that("DS follows the raw special-event mapping and no-day-zero convention", {
  raw <- pharmaverseraw::ds_raw
  expect_equal(nrow(ds), nrow(raw))
  expect_equal(ncol(ds), 12L)
  expect_false(anyDuplicated(ds[c("USUBJID", "DSSEQ")]) > 0)
  expect_false(any(ds$DSSTDY == 0, na.rm = TRUE))
  expect_equal(sum(ds$DSCAT == "OTHER EVENT"), sum(!is.na(raw$OTHERSP) & nzchar(raw$OTHERSP)))
  expect_true(all(ds$DSTERM[ds$DSCAT == "OTHER EVENT"] == ds$DSDECOD[ds$DSCAT == "OTHER EVENT"]))
  expect_true(all(ds$DSDECOD[ds$DSCAT == "PROTOCOL MILESTONE"] == "RANDOMIZED"))
  sample <- raw[rep(1, 3), ]
  sample$IT.DSSTDAT <- c("01-01-2020", "01-02-2020", "01-03-2020")
  reference <- pharmaversesdtm::dm |> filter(USUBJID == paste0("01-", sample$PATNUM[1]))
  reference$RFSTDTC <- "2020-01-02"
  expect_equal(create_ds(sample, reference)$DSSTDY, c(-1L, 1L, 2L))
})

test_that("TLG counts reconcile with independent source calculations", {
  source("question_4_tlg/common.R", local = TRUE)
  tlg <- get_tlg_data()
  counts <- read.csv("outputs/ae_summary_counts.csv")
  expect_true(all(counts$n <= counts$N))
  all_overall <- subset(counts, AESOC == "All subjects" & ACTARM == "Overall")
  expect_equal(all_overall$N, nrow(tlg$population))
  for (i in seq_len(nrow(counts))) {
    row <- counts[i, ]
    subset_events <- tlg$events
    if (row$ACTARM != "Overall") subset_events <- subset_events |> filter(ACTARM == row$ACTARM)
    if (row$AESOC == "All subjects") next
    if (row$AESOC != "Any TEAE") subset_events <- subset_events |> filter(AESOC == row$AESOC)
    expect_equal(row$n, n_distinct(subset_events$USUBJID))
  }
  listing <- read.csv("outputs/ae_listings.csv")
  expect_equal(nrow(listing), sum(pharmaverseadam::adae$TRTEMFL == "Y", na.rm = TRUE))
  top <- read.csv("outputs/ae_top10_counts.csv")
  expect_true(all(top$lower >= 0 & top$upper <= 1))
  expect_true(all(top$lower <= top$proportion & top$proportion <= top$upper))
})
