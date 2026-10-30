source("scripts/common.R")
scripts <- c("question_2_sdtm/02_create_ds_domain.R", "question_3_adam/create_adsl.R",
             "question_4_tlg/01_create_ae_summary_table.R",
             "question_4_tlg/02_create_visualizations.R",
             "question_4_tlg/03_create_listings.R", "scripts/export_api_data.R")
for (script in scripts) {
  message("Running ", script)
  source(script, local = new.env(parent = globalenv()))
}
capture.output(sessionInfo(), file = "outputs/R-session-info.txt")
write.csv(as.data.frame(installed.packages()[, c("Package", "Version")]),
          "outputs/R-package-versions.csv", row.names = FALSE)
message("Completed. Data and reports are in outputs/; API input is data/adae.csv.")
