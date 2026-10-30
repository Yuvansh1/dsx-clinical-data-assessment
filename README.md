# Clinical data assessment: complete solution

All six questions are implemented. Generated datasets, HTML tables and PNG charts
are included in `outputs/`. No watermarks, logos or promotional footers are added.
The data are the public Pharmaverse example datasets specified in the assessment.

## Start here

Run commands from this folder. Install Python 3.11 and R >= 4.2 and add them to
PATH. Local runtimes, installed libraries and caches are excluded from this
submission. Set up the dependencies first:

```sh
python -m venv .venv
Windows: .venv\Scripts\activate
python -m pip install -r requirements.txt
Rscript scripts/install_packages.R
Rscript scripts/run_all.R
Rscript scripts/check_package.R
& "C:\Program Files\R\R-<version>\bin\R.exe" CMD INSTALL question_1/descriptive_stats
 python -m pytest -q
python -m uvicorn question_5_api.main:app --reload
```

Open http://127.0.0.1:8000/docs to exercise the API. In another activated terminal,
run `python -m question_6_genai.agent --mode mock` for the three assistant examples.
Run `python scripts/validate.py` for complete validation, including R package checks.

R packages are installed into `.Rlibrary/`, and every R script loads that local
library automatically. Internet access is needed for initial dependency installation;
the R pipeline and Python mock mode then run without network access. The exact R
package versions used for generated outputs are recorded in
`outputs/R-package-versions.csv`; Python's full environment is in
`requirements-lock.txt`. Use `python -m pip install -r requirements-lock.txt` to
reproduce the tested Python versions.

## Repository layout and deliverables

| Question | Implementation | Deliverables |
|---|---|---|
| 1 | `question_1/descriptive_stats/` | Installable descriptiveStats package, six documented functions, generated `man/` pages, testthat tests |
| 2 | `question_2_sdtm/02_create_ds_domain.R` | `outputs/ds.csv`, `outputs/ds.rds` with all 12 requested variables |
| 3 | `question_3_adam/create_adsl.R` | `outputs/adsl.csv`, `outputs/adsl.rds`, one row per DM subject |
| 4 | Three scripts in `question_4_tlg/` | `ae_summary_table.html`, `ae_listings.html`, `ae_severity.png`, `ae_top10.png` in `outputs/` |
| 5 | `question_5_api/main.py` | FastAPI welcome, cohort and risk endpoints; interactive `/docs` |
| 6 | `question_6_genai/agent.py` | LangChain prompt, validated JSON plan, pandas execution; live and mock modes |
| Shared | `scripts/`, `tests/`, `data/` | Full pipeline, export, validation, API input and source provenance |

RDS files preserve R Date/POSIXct types. CSV uses readable ISO dates and datetimes.
Numeric date/datetime values in R use R's epoch, not SAS's epoch; no XPT export is
claimed. This is the requested assessment subset, not a complete regulatory submission.

## Question 1: statistics

```r
library(descriptiveStats)
x <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
calc_mean(x)    # 4.3
calc_median(x)  # 4.5
calc_mode(x)    # 5
calc_q1(x)      # 2.25
calc_q3(x)      # 5
calc_iqr(x)     # 2.75
```

These correct several arithmetic errors in the PDF's example. Quartiles use R's
type 7 interpolation. All functions accept `na.rm`; missing data propagate by
default. Numeric summaries of empty vectors return NA; mode returns all tied
repeated values, or `numeric(0)` when no value repeats. Infinite and nonnumeric
inputs are rejected. The package README explains the neutral maintainer metadata
to replace with your own name and email before publication.

## Question 2: disposition mapping

Uses `sdtm.oak::generate_oak_id_vars`, `assign_no_ct`, `assign_ct` and
`assign_datetime`. Data are joined by stable source row IDs. The supplied study CT
is embedded, with explicit spelling normalization and a study mapping for
RANDOMIZED (no invented NCI term code). Unknown reasons fail with an error.

The linked aCRF says `IT.DSSDAT`, but the actual package column is `IT.DSSTDAT`;
the actual dates use MM-DD-YYYY. `OTHERSP` overrides both DSTERM and DSDECOD and
sets DSCAT to OTHER EVENT. Randomization is a PROTOCOL MILESTONE; remaining rows
are DISPOSITION EVENT. Terms are uppercased after mapping. INSTANCE maps to
uppercase VISIT; VISITNUM comes from the unique visit-name mapping in the supplied
SDTM SV data. Unmatched visit names stop the run.

USUBJID follows the example study convention `01-` + PATNUM and is validated
against DM. DSSTDY is relative to DM.RFSTDTC with no day zero. Missing/partial
dates do not receive invented study days. Sequence numbers are assigned within
subject after deterministic date/term/source-row sorting.

## Question 3: ADSL derivations

| Variable | Derivation |
|---|---|
| AGEGR9 / AGEGR9N | `<18`/1, `18 - 50`/2, `>50`/3; missing age stays missing |
| TRTSDTM / TRTSTMF | Earliest complete-date, valid-dose EX start; admiral imputes missing time with zeroes |
| TRTEDTM / TRTETMF | Latest valid-dose EX end; complete start is used when end is unavailable; missing end time becomes end-of-day |
| ITTFL | Y for nonblank ARM, otherwise N |
| ABNSBPFL | Y for SYSBP in mmHg with result <100 or >=140; otherwise N |
| LSTALVDT | Maximum complete valid-result VS date, AE onset, DS date or treatment end date |
| CARPOPFL | Y for case-insensitive CARDIAC DISORDERS, otherwise missing |

A valid dose is EXDOSE >0, or zero dose with PLACEBO in EXTRT. Partial dates are
not imputed. Time imputation uses admiral with seconds detection enabled; `S`
flags are then cleared to implement the PDF's explicit seconds-only exception
even when some records contain seconds. `H` and `M` flags are retained.

The introductory text mentions supine BP, but the detailed formula does not
require VSPOS. The implementation follows the detailed formula and includes all
positions. The detailed last-alive formula is also followed, including all DS
records; it does not add an unrequested death-record exclusion. UTC is used for
consistent date conversions, not as a claim about original collection time zones.

## Question 4: reports

The summary and graphs use ADSL's safety population (`SAFFL == "Y"`) with a
nonblank ACTARM, joined to ADAE TEAEs (`TRTEMFL == "Y"`). The summary reports
unique subjects per SOC and arm, with **all safety subjects** as denominators.
It includes All subjects, Any TEAE and an Overall column. Repeated events within
a SOC do not inflate its numerator. SOC rows are sorted by overall frequency.

The severity chart deliberately counts **events**, including recurrent events.
The top-ten chart counts **subjects** per AETERM and uses 95% Wilson intervals
for incidence proportions, not person-time rates. Tie-breaking is alphabetical.
Supporting CSV counts allow independent reconciliation.

The listing includes every TEAE row from ADAE, ordered by subject, start date
and AESEQ. It displays subject, treatment, term, severity, relationship and dates.
Both HTML tables use `gtsummary::as_gtsummary()` and `as_gt()` to render the
explicitly prepared table bodies. This avoids summarizing away individual listing
rows or accidentally using AE-record counts as population denominators.

## Question 5: API

`data/adae.csv` contains `pharmaversesdtm::ae` joined to DM for ACTARM. The PDF
uses the filename adae.csv while specifying SDTM AE as its input; that naming
inconsistency is preserved explicitly. It is separate from Question 4's ADaM ADAE.
The file is loaded and validated once at application startup. To use another
compatible CSV, set `CLINICAL_DATA_PATH` before starting the server.

```powershell
Invoke-RestMethod http://127.0.0.1:8000/
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8000/ae-query `
  -ContentType 'application/json' `
  -Body '{"severity":["MILD","MODERATE"],"treatment_arm":"Placebo"}'
Invoke-RestMethod http://127.0.0.1:8000/subject-risk/01-701-1015
```

`POST /ae-query` returns `count` (matching **event rows**) and sorted unique
`subject_ids`. Filters combine with AND; omitted/null filters are ignored. An
empty severity list matches nothing. Severity and treatment comparisons ignore
case. Bad severity values, unknown request fields and blank arms return 422.

Risk sums all of a subject's AE rows using MILD=1, MODERATE=3, SEVERE=5. Scores
below 5 are Low, 5–14 Medium, and >=15 High. A subject absent from the AE input
returns 404, including a DM subject with no recorded AE. Missing or unsupported
severity in the input is rejected at startup rather than silently assigned zero.
This score is the assessment's formula, not a validated clinical risk prediction.

## Question 6: assistant

```powershell
# No credentials required: three deterministic examples.
.venv\Scripts\python.exe -m question_6_genai.agent --mode mock

# Optional real LLM; provide your key through the environment.
$env:OPENAI_API_KEY = '<your-key>'
.venv\Scripts\python.exe -m question_6_genai.agent --mode live `
  --model gpt-4.1-mini --question 'Which subjects had cardiac adverse events?'
```

The model sees column definitions and the question, not the clinical dataframe.
It generates `target_column`, `filter_value` and `match_mode`. Pydantic restricts
columns and operations, then pandas executes case-insensitive equality or literal
substring matching (`regex=False`). Results contain unique subject counts and IDs.
No `eval`, generated Python execution, or keyword-routing rules are used.

Mock mode replays three predetermined model responses in order through the same
prompt/parser/executor chain. It is a demonstration, not an intelligent offline
model; arbitrary questions require live mode. Invalid plans fail validation.
The supported scope is one positive filter per question; compound conditions,
negation and unrelated requests are rejected via an invalid-plan response.

The live path is implemented but not verified against a paid service: no user API
key was supplied. Model access depends on your account; `--model` is configurable.
The default model is documented as deprecated with shutdown planned for January
14, 2027; choose an available Chat Completions model when needed and check its
supported parameters. See the official references below.

## Tests and submission

`scripts/validate.py` rebuilds all outputs, generates package documentation,
runs R unit/clinical tests, builds and checks the R package, tests the Python API
and agent, and runs the three example queries. Logs are written to
`outputs/validation/`. `R CMD check` uses `--no-manual` because a LaTeX toolchain
is unnecessary for HTML help and the requested deliverables.

Submit this folder's contents in a public GitHub repository and provide its URL,
as requested by the assessment. Include the six question folders, README, package
documentation/tests, dependencies, supporting scripts, input data and generated
reports. Local environments, caches, build artifacts and execution logs have been
removed. Validation regenerates its logs when run. No repository has been published
on your behalf.

## References

- [sdtm.oak mapping functions](https://pharmaverse.github.io/sdtm.oak/reference/assign.html)
- [sdtm.oak ISO date mapping](https://pharmaverse.github.io/sdtm.oak/reference/assign_datetime.html)
- [Disposition aCRF](https://github.com/pharmaverse/pharmaverseraw/blob/main/vignettes/articles/aCRFs/Subject_Disposition_aCRF.pdf)
- [admiral datetime derivation](https://pharmaverse.github.io/admiral/cran-release/reference/derive_vars_dtm.html)
- [gtsummary table construction](https://www.danieldsjoberg.com/gtsummary/reference/as_gtsummary.html)
- [Official OpenAI model documentation](https://developers.openai.com/api/docs/models/gpt-4.1-mini)
- [Official OpenAI Chat Completions reference](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
