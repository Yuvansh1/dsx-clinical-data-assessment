source("scripts/common.R")
# The PDF names adae.csv but specifies pharmaversesdtm::ae as its source.
# Join DM to supply ACTARM, which is absent from SDTM AE; preserve every AE row.
ae <- pharmaversesdtm::ae
dm <- pharmaversesdtm::dm |> select(USUBJID, ACTARM)
stopifnot(!anyDuplicated(dm$USUBJID), all(ae$USUBJID %in% dm$USUBJID))
api_data <- ae |> left_join(dm, by = "USUBJID")
stopifnot(nrow(api_data) == nrow(ae))
write.csv(api_data, "data/adae.csv", row.names = FALSE, na = "")
writeLines(c("Source: pharmaversesdtm::ae joined to pharmaversesdtm::dm by USUBJID.",
             "Filename adae.csv follows the assessment; this is not a derived ADaM ADAE.",
             paste("Rows:", nrow(api_data)), paste("Subjects:", n_distinct(api_data$USUBJID))),
           "data/PROVENANCE.txt")
