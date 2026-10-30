source("question_4_tlg/common.R")
# All treatment-emergent ADAE rows, as requested (no safety-population restriction).
listing <- pharmaverseadam::adae |>
  filter(TRTEMFL == "Y") |> select(-any_of("ACTARM")) |>
  left_join(pharmaverseadam::adsl |> select(USUBJID, ACTARM), by = "USUBJID") |>
  arrange(USUBJID, ASTDT, AESEQ) |>
  transmute(`Subject ID` = USUBJID, Treatment = ACTARM, `AE term` = AETERM,
            Severity = AESEV, Relationship = AEREL,
            `Start date` = as.character(ASTDT), `End date` = as.character(AENDT))
save_table(listing, "ae_listings.html", "Treatment-emergent adverse event listing",
           "All treatment-emergent events; ordered by subject, start date and source sequence. Blank end dates indicate missing dates.")
write.csv(listing, "outputs/ae_listings.csv", row.names = FALSE, na = "")
