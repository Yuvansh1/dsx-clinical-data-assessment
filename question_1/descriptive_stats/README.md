# descriptiveStats

Install from the repository root with `R CMD INSTALL question_1/descriptive_stats`.
The six exported functions accept a numeric vector and optional `na.rm = TRUE`.
Missing values propagate by default; empty numeric summaries return `NA_real_`.
Quartiles use R's default type 7 interpolation. Modes return all tied repeated
values, sorted; a vector with no repeated value has no mode (`numeric(0)`).
Infinite values, matrices, factors and other nonnumeric inputs are rejected.

The assessment's vector has mean **4.3**, median **4.5**, mode **5**, Q1 **2.25**,
Q3 **5**, and IQR **2.75**. Several printed expected values in the PDF are incorrect.

Run `testthat::test_local("question_1/descriptive_stats")` to execute the tests.
Package metadata uses a neutral maintainer placeholder; replace it with your
own name and email before publishing the package.
