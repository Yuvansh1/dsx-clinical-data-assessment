source("question_4_tlg/common.R")
tlg <- get_tlg_data()
events <- tlg$events
population <- tlg$population
severity <- events |> mutate(AESEV = coalesce(na_if(AESEV, ""), "Not reported")) |>
  count(ACTARM, AESEV, name = "Events")
p1 <- ggplot(severity, aes(ACTARM, Events, fill = AESEV)) +
  geom_col(position = "dodge") +
  scale_fill_brewer(palette = "Set2") +
  labs(title = "TEAE severity by treatment", x = NULL, y = "Number of events", fill = "Severity",
       caption = "Safety population; event counts, including recurrent events.") +
  theme_minimal(base_size = 12) + theme(legend.position = "bottom")
ggsave("outputs/ae_severity.png", p1, width = 10, height = 6, dpi = 180, bg = "white")

# Incidence is a subject proportion, not an exposure-adjusted event rate.
top <- events |> distinct(USUBJID, AETERM) |> count(AETERM, name = "n") |>
  arrange(desc(n), AETERM) |> slice_head(n = 10) |>
  mutate(N = nrow(population), proportion = n / N)
# Wilson score interval, bounded in [0,1], with z = 1.959964.
z <- qnorm(0.975)
top <- top |> mutate(center = (proportion + z^2 / (2 * N)) / (1 + z^2 / N),
                     half = z * sqrt(proportion * (1 - proportion) / N + z^2 / (4 * N^2)) /
                       (1 + z^2 / N),
                     lower = pmax(0, center - half), upper = pmin(1, center + half),
                     AETERM = factor(AETERM, levels = rev(AETERM)))
p2 <- ggplot(top, aes(proportion * 100, AETERM)) +
  geom_segment(aes(x = lower * 100, xend = upper * 100, yend = AETERM), color = "#52697C") +
  geom_point(size = 3, color = "#146C94") +
  labs(title = "Ten most frequent treatment-emergent adverse events",
       x = "Subjects with event (%) and 95% Wilson confidence interval", y = NULL,
       caption = paste("Safety population; overall N =", nrow(population),
                       ". Each subject counted once per term.")) +
  theme_minimal(base_size = 12)
ggsave("outputs/ae_top10.png", p2, width = 11, height = 7, dpi = 180, bg = "white")
write.csv(top, "outputs/ae_top10_counts.csv", row.names = FALSE)
