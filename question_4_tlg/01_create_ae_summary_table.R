source("question_4_tlg/common.R")
tlg <- get_tlg_data()
population <- tlg$population
events <- tlg$events
arms <- population |> count(ACTARM, name = "N")
# One record per subject and SOC. Subjects with no TEAE remain in denominators.
counts <- events |> distinct(USUBJID, ACTARM, AESOC) |> count(AESOC, ACTARM, name = "n")
grid <- expand_grid(AESOC = sort(unique(events$AESOC)), ACTARM = arms$ACTARM) |>
  left_join(counts, by = c("AESOC", "ACTARM")) |>
  mutate(n = coalesce(n, 0L)) |> left_join(arms, by = "ACTARM")
overall <- events |> distinct(USUBJID, AESOC) |> count(AESOC, name = "n") |>
  mutate(ACTARM = "Overall", N = nrow(population))
total <- bind_rows(arms |> mutate(AESOC = "All subjects", n = N),
                   tibble(AESOC = "All subjects", ACTARM = "Overall",
                          n = nrow(population), N = nrow(population)))
any_event <- events |> distinct(USUBJID, ACTARM) |> count(ACTARM, name = "n") |>
  right_join(arms, by = "ACTARM") |> mutate(n = coalesce(n, 0L), AESOC = "Any TEAE")
any_event <- bind_rows(any_event, tibble(AESOC = "Any TEAE", ACTARM = "Overall",
                       n = n_distinct(events$USUBJID), N = nrow(population)))
order_soc <- overall |> arrange(desc(n), AESOC) |> pull(AESOC)
summary_counts <- bind_rows(total, any_event, grid, overall)
stopifnot(all(summary_counts$n <= summary_counts$N))
table <- summary_counts |>
  mutate(cell = sprintf("%d (%.1f%%)", n, 100 * n / N),
         group = paste0(ACTARM, " (N=", N, ")"),
         AESOC = factor(AESOC, levels = c("All subjects", "Any TEAE", order_soc))) |>
  select(AESOC, group, cell) |> pivot_wider(names_from = group, values_from = cell) |>
  arrange(AESOC) |> rename(`System organ class` = AESOC)
save_table(table, "ae_summary_table.html", "Treatment-emergent adverse events",
           "Safety population. Cells are unique subjects n (%); denominator is all safety subjects in each arm. Subjects may occur in multiple organ classes. SOC rows sorted by overall subject frequency.")
write.csv(summary_counts, "outputs/ae_summary_counts.csv", row.names = FALSE)
