# DSX Clinical Data Assessment

This repository contains solutions to all six questions in the DSX assessment. It follows the data from raw disposition records through SDTM and ADaM derivations, adverse-event reports, a FastAPI service, and a LangChain query assistant. Each question has its own folder so that the code and its outputs can be reviewed together.

The examples use the public Pharmaverse datasets specified in the assessment. Generated datasets and reports are included in [outputs/](outputs/), so they can be inspected before installing R or Python.

## 1. Requirements and deliverables

| Question | Implementation | Deliverables |
|---|---|---|
| 1. Descriptive statistics | [question_1/descriptive_stats/](question_1/descriptive_stats/) | Installable package, six functions, Roxygen documentation, help pages, tests, and package README |
| 2. SDTM disposition | [02_create_ds_domain.R](question_2_sdtm/02_create_ds_domain.R) | Mapping with `sdtm.oak`; all 12 requested variables; CSV and RDS outputs |
| 3. Subject-level analysis | [create_adsl.R](question_3_adam/create_adsl.R) | ADSL based on DM, including the requested age groups, treatment datetime, flags, and last-alive date |
| 4. Adverse-event reports | [question_4_tlg/](question_4_tlg/) | Separate summary, visualization, and listing scripts; two HTML reports and two PNG charts |
| 5. Clinical data API | [main.py](question_5_api/main.py) | Welcome endpoint, optional cohort filters, and subject risk scores |
| 6. Query assistant | [agent.py](question_6_genai/agent.py) | Schema-aware prompt, validated JSON, pandas filtering, and three example queries |

[scripts/](scripts/) contains dependency installation, data export, package checks, and the validation runner. [tests/](tests/) checks clinical derivations and Python behavior. [data/PROVENANCE.txt](data/PROVENANCE.txt) identifies the API input source.

The coding deliverables are present. Final submission also requires a **public GitHub repository and a two-minute screen-share video**. The checklist at the end separates those steps from local implementation.

## 2. Setup and execution

Use **R 4.2 or later** and **Python 3.10 or later**. This review used R 4.6.1 and Python 3.10.20 on Windows. Run commands from the repository root.

### Windows PowerShell

Ensure `Rscript.exe` and `R.exe` are on PATH. The first line below uses the R installation available during this review; adjust its version if needed. It changes PATH only for the current terminal.

```powershell
$env:PATH = 'C:\Program Files\R\R-4.6.1\bin;' + $env:PATH
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-lock.txt
Rscript scripts/install_packages.R
.venv\Scripts\python.exe scripts/validate.py
```

Calling the virtual environment's Python directly avoids a separate activation step. Validation rebuilds the outputs and runs the checks described in section 8. To regenerate only datasets and reports, run `Rscript scripts/run_all.R`.

### macOS or Linux

With R and Python installed and on PATH:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
Rscript scripts/install_packages.R
.venv/bin/python scripts/validate.py
```

These Unix commands are provided for convenience; this review ran on Windows. Initial dependency installation needs internet access. After installation, the data pipeline and mock assistant use local data. R package checks may still attempt to contact package repositories.

R dependencies are installed in `.Rlibrary/`, which the scripts load automatically. [requirements.txt](requirements.txt) lists direct Python dependencies; [requirements-lock.txt](requirements-lock.txt) records the tested environment. R versions are recorded in [R-package-versions.csv](outputs/R-package-versions.csv) and [R-session-info.txt](outputs/R-session-info.txt). The R installer uses available repository versions rather than restoring a locked R environment.

## 3. Question 1: descriptive statistics

Install the package from an R session opened at the repository root:

```r
install.packages("question_1/descriptive_stats", repos = NULL, type = "source")
library(descriptiveStats)

x <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
calc_mean(x)    # 4.3
calc_median(x)  # 4.5
calc_mode(x)    # 5
calc_q1(x)      # 2.25
calc_q3(x)      # 5
calc_iqr(x)     # 2.75
```

Some expected values printed in the PDF do not match its example vector. The results above use the actual arithmetic and R's type 7 quartiles.

All functions accept `na.rm`. Missing values propagate unless removal is requested. Empty numeric summaries return `NA_real_`; mode returns all tied, repeated values or `numeric(0)` when nothing repeats. Infinite values, matrices, and nonnumeric inputs produce an informative error. See the [package README](question_1/descriptive_stats/README.md) for details.

## 4. Questions 2 and 3: clinical datasets

### SDTM DS

The DS script reads `pharmaverseraw::ds_raw` and uses `sdtm.oak` assignment functions for terms and ISO dates. It preserves one record per source row and joins mapped values using stable source identifiers.

The main mapping decisions are:

- Use the assessment's study controlled terminology, with normalization of known spelling variants. Unmapped reasons stop the run.
- When `OTHERSP` is populated, use it for both `DSTERM` and `DSDECOD` and assign `OTHER EVENT`. Otherwise, randomization is a `PROTOCOL MILESTONE` and remaining records are `DISPOSITION EVENT`.
- Read `IT.DSSTDAT`, the actual dataset column corresponding to `IT.DSSDAT` in the linked aCRF. Source dates are month-day-year.
- Map `INSTANCE` to uppercase `VISIT`, obtain `VISITNUM` from SV, and validate subject identifiers against DM.
- Derive `DSSTDY` relative to `RFSTDTC`, with no day zero. Missing or partial dates do not receive an invented study day. Assign `DSSEQ` after deterministic sorting.

[ds.csv](outputs/ds.csv) contains **850 rows and 12 variables**: `STUDYID`, `DOMAIN`, `USUBJID`, `DSSEQ`, `DSTERM`, `DSDECOD`, `DSCAT`, `VISITNUM`, `VISIT`, `DSDTC`, `DSSTDTC`, and `DSSTDY`.

### ADaM ADSL

The ADSL script starts from `pharmaversesdtm::dm` and retains one row for each of its **306 subjects**. It uses `admiral` for treatment datetime derivation.

| Variable | Rule used |
|---|---|
| `AGEGR9`, `AGEGR9N` | Below 18 = 1; 18 through 50 = 2; above 50 = 3. Missing age stays missing. |
| `TRTSDTM`, `TRTSTMF` | Earliest complete-date exposure with a valid dose; missing time components become zero. Keep hour/minute imputation flags and clear a seconds-only flag. |
| `TRTEDTM`, `TRTETMF` | Latest valid-dose exposure end; use a complete start when the end is unavailable. Missing end time becomes end-of-day. |
| `ITTFL` | `Y` when `ARM` is populated; otherwise `N`. |
| `ABNSBPFL` | `Y` for a systolic result in mmHg below 100 or at least 140; otherwise `N`. |
| `LSTALVDT` | Latest complete date across valid-result vital signs, AE onset, disposition, and treatment end. |
| `CARPOPFL` | `Y` for a `CARDIAC DISORDERS` AE, ignoring case; otherwise missing. |

A valid dose means `EXDOSE > 0`, or zero dose with `PLACEBO` in `EXTRT`. Partial dates are not imputed. The introduction mentions supine blood pressure, but the detailed formula has no position condition. The code follows the detailed formula and includes all positions. It also includes all disposition records in the last-alive calculation, as specified.

Both datasets are saved as CSV and RDS. RDS preserves R date and datetime types; CSV contains readable ISO values. Numeric dates use R's epoch. These are the assessment's requested datasets, without a claim of full submission compliance or SAS XPT compatibility. UTC keeps conversions consistent; it does not identify the original collection time zone.

## 5. Question 4: adverse-event reports

The reports use `pharmaverseadam::adae` and `pharmaverseadam::adsl`.

| Output | How to read it |
|---|---|
| [AE summary](outputs/ae_summary_table.html) | Unique subjects with TEAEs by organ class and treatment, shown as counts and percentages |
| [Severity chart](outputs/ae_severity.png) | Event counts by severity and treatment, including recurrent events |
| [Top ten AEs](outputs/ae_top10.png) | Subject incidence proportions with 95% Wilson confidence intervals |
| [AE listing](outputs/ae_listings.html) | All 1,122 treatment-emergent records, ordered by subject, start date, and source sequence |

The summary and charts use the safety population with an assigned actual arm: **254 subjects**. Percentages include all safety subjects in the relevant arm as the denominator, including those without a TEAE. A subject counts once within each organ class or AE term. The summary includes All subjects, Any TEAE, and Overall results; organ classes are sorted by overall subject frequency.

The top-ten chart treats incidence as a subject proportion rather than a person-time rate. Alphabetical order resolves frequency ties. The listing includes subject, treatment, term, severity, relationship, and start/end dates, without an additional safety-population restriction.

Both HTML reports use `gtsummary::as_gtsummary()` and `as_gt()` to render prepared table bodies. Supporting CSVs retain the counts and listing rows for checking.

## 6. Question 5: FastAPI service

Start the server in PowerShell:

```powershell
.venv\Scripts\python.exe -m uvicorn question_5_api.main:app --reload
```

Open [the interactive API documentation](http://127.0.0.1:8000/docs), or run these requests in another terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/ae-query `
  -ContentType 'application/json' `
  -Body '{"severity":["MILD","MODERATE"],"treatment_arm":"Placebo"}'
Invoke-RestMethod http://127.0.0.1:8000/subject-risk/01-701-1015
```

| Endpoint | Behavior |
|---|---|
| `GET /` | Returns the required welcome message. |
| `POST /ae-query` | Applies every supplied filter; returns the matching event-row count and sorted unique subject IDs. Missing or null filters are ignored. |
| `GET /subject-risk/{subject_id}` | Sums severity weights: mild = 1, moderate = 3, severe = 5. Below 5 is Low; 5 through 14 is Medium; 15 or more is High. |

Filters ignore case. An empty severity list matches no records. Invalid severity values, blank arms, and unknown fields return 422. A subject absent from the AE input returns 404, including a DM subject without recorded AEs.

The API reads [data/adae.csv](data/adae.csv) once at startup. It contains **1,191 SDTM AE records for 225 subjects**, joined to DM for `ACTARM`. The filename follows the PDF, which names the file `adae.csv` while specifying `pharmaversesdtm::ae` as its source. It is separate from the ADaM data used in Question 4.

Set `CLINICAL_DATA_PATH` to use another compatible CSV. Required columns and severity values are checked at startup. The risk score implements the exercise formula; it has not been validated as a clinical prediction model.

## 7. Question 6: natural-language queries

Run the three examples without credentials:

```powershell
.venv\Scripts\python.exe -m question_6_genai.agent --mode mock
```

They ask about moderate severity, headache, and cardiac adverse events. Each request follows the same path: a prompt containing the schema, a JSON response, Pydantic validation, and a pandas filter. Results include the interpreted query, unique subject count, and subject IDs.

Allowed columns are `AESEV`, `AETERM`, `AESOC`, `ACTARM`, and `USUBJID`. Matching supports case-insensitive equality or literal substring searches. The executor does not run model-generated Python. A query supports one positive filter. The prompt requests an invalid-plan response for unsupported questions, which the parser rejects; live model adherence has not been verified.

Mock mode replays three fixed responses in order, as permitted by the PDF. It demonstrates the complete flow but cannot interpret a new question. Live mode needs your own API key and a model available to your account:

```powershell
# Set OPENAI_API_KEY in your environment before running this command.
.venv\Scripts\python.exe -m question_6_genai.agent --mode live `
  --model '<available-model-id>' `
  --question 'Which subjects had cardiac adverse events?'
```

The default identifier in the code is `gpt-4.1-mini`; use `--model` to override it. The prompt sends the schema and question, not the clinical dataframe. Live service access was not tested. Mock mode meets the assessment's explicit alternative for candidates without an API key.

## 8. Validation

Run `.venv\Scripts\python.exe scripts/validate.py` on Windows. It regenerates outputs, builds documentation, runs R and Python tests, checks the R package, exercises the API against the exported data, and runs the three assistant examples. Logs are saved in `outputs/validation/`.

Checks cover numerical edge cases, age boundaries, dose rules, time imputation, last-alive dates, DS mapping, study days, report counts, API filters, risk thresholds, and query-plan execution. The charts were also inspected for readable labels and confidence intervals. The latest local review passed all 15 Python tests and 168 R assertions, with `R CMD check` returning `Status: OK`.

`R CMD check` uses `--no-manual`, so it does not need LaTeX. HTML help and examples are still checked. Fresh dependency downloads and paid LLM access were not part of the local functional checks.

## 9. Sources and use of AI

This README explains the implementation and its decisions in project-specific language. Standard variable names and required formulas retain their original meaning. The assessment, datasets, and package references are credited below.

AI assistance was used to review the code and revise the documentation. The assessment explicitly permits coding assistants. No plagiarism-checking service was used, so this repository does not claim a similarity score or certification.

- DSX Data Scientist Coding Assessment, supplied PDF: questions on pages 5-17 and submission instructions on page 3.
- [Pharmaverse examples](https://pharmaverse.github.io/examples/) and the `pharmaverseraw`, `pharmaversesdtm`, and `pharmaverseadam` datasets.
- [Disposition aCRF and programming annotations](https://github.com/pharmaverse/pharmaverseraw/blob/main/vignettes/articles/aCRFs/Subject_Disposition_aCRF.pdf).
- [sdtm.oak](https://pharmaverse.github.io/sdtm.oak/) for SDTM mapping.
- [admiral](https://pharmaverse.github.io/admiral/) for analysis datetime derivation.
- [gtsummary](https://www.danieldsjoberg.com/gtsummary/) for report construction.

## 10. Before submitting

- [x] Include all six question folders, documentation, tests, input data, and generated outputs.
- [x] Compare the implementation with the PDF and document interpretation choices.
- [ ] Replace the neutral author and email in the package `DESCRIPTION` and the holder in `LICENSE` with your own details.
- [x] Create a public repository: [Yuvansh1/dsx-clinical-data-assessment](https://github.com/Yuvansh1/dsx-clinical-data-assessment). Public visibility was verified on October 30, 2026.
- [ ] Commit and push the reviewed local changes so the public repository includes this revision.
- [ ] Record and upload the required two-minute screen-share walkthrough.
- [ ] Submit both the repository link and video link through the Phenom interview process.

Use this outline for the video, describing your own approach and experience:

| Time | What to show and explain |
|---|---|
| 0:00-0:20 | Repository structure and how the six solutions fit together. |
| 0:20-0:50 | Statistics package and one DS/ADSL derivation; explain a date-handling decision. |
| 0:50-1:15 | AE summary and charts; explain event counts versus subject counts. |
| 1:15-1:40 | An API filter and an assistant example, clearly identifying mock mode. |
| 1:40-2:00 | Validation results, one challenge, and what you learned. |

Local environments, credentials, agent settings, review notes, validation logs, and package build artifacts are excluded by `.gitignore`. Keep the data export, generated reports, and documentation in the submitted repository.
