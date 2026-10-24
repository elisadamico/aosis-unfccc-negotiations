# =============================================================================
# 02_overview.R
# A first look at the clean data: three descriptive figures and one table.
# These are starting points, not results. Run 01_clean.R first.
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

panel    <- read_csv("data/clean/panel_meeting_actor.csv", show_col_types = FALSE)
meetings <- read_csv("data/clean/meetings.csv", show_col_types = FALSE)

# COPs from Copenhagen (2009) onwards
cops <- panel |>
  filter(meeting_type == "COP", year >= 2009) |>
  mutate(cop = factor(paste0("COP", cop_number, "\n", year),
                      levels = unique(paste0("COP", cop_number, "\n", year))))

# Shade the COPs held under a Trump administration
trump_cops <- cops |>
  distinct(cop, us_admin) |>
  mutate(x = as.numeric(cop)) |>
  filter(us_admin %in% c("Trump 1", "Trump 2"))

shade <- function() {
  geom_rect(data = trump_cops, inherit.aes = FALSE,
            aes(xmin = x - 0.5, xmax = x + 0.5, ymin = -Inf, ymax = Inf),
            fill = "grey85")
}

theme_thesis <- theme_minimal(base_family = "Times New Roman", base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        legend.position = "bottom",
        legend.title = element_blank())


# Figure 1. Share of all interventions at each COP: AOSIS vs comparison groups
fig1 <- cops |>
  filter(actor %in% c("AOSIS", "EU", "LDCs", "G-77/China")) |>
  ggplot(aes(cop, share_interventions, colour = actor, group = actor)) +
  shade() +
  geom_line() +
  geom_point() +
  scale_y_continuous(labels = scales::percent) +
  labs(x = NULL, y = "Share of all interventions") +
  theme_thesis

ggsave("output/figures/fig1_share_interventions_cops.png", fig1,
       width = 9, height = 4.5, dpi = 300, bg = "white")


# Figure 2. The US "treatment": US share of interventions at each COP
fig2 <- cops |>
  filter(actor == "United States") |>
  ggplot(aes(cop, share_interventions, group = 1)) +
  shade() +
  geom_line() +
  geom_point() +
  scale_y_continuous(labels = scales::percent) +
  labs(x = NULL, y = "US share of all interventions") +
  theme_thesis

ggsave("output/figures/fig2_us_share_cops.png", fig2,
       width = 9, height = 4, dpi = 300, bg = "white")


# Figure 3. Support and opposition received by AOSIS at each COP
fig3 <- cops |>
  filter(actor == "AOSIS") |>
  select(cop, Support = support_received, Opposition = opposition_received) |>
  pivot_longer(-cop) |>
  ggplot(aes(cop, value, fill = name)) +
  shade() +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c(Opposition = "#b2182b", Support = "#2166ac")) +
  labs(x = NULL, y = "Interactions directed at AOSIS") +
  theme_thesis

ggsave("output/figures/fig3_aosis_support_opposition_cops.png", fig3,
       width = 9, height = 4, dpi = 300, bg = "white")


# Table. Average AOSIS share of interventions by US administration (all
# negotiating meetings, not only COPs), with the EU and LDCs for comparison
tab <- panel |>
  filter(meeting_type != "other", year >= 2009,
         actor %in% c("AOSIS", "EU", "LDCs", "United States")) |>
  group_by(us_admin, actor) |>
  summarise(meetings = n(),
            mean_share = mean(share_interventions, na.rm = TRUE),
            .groups = "drop") |>
  mutate(us_admin = factor(us_admin, levels = c("Obama", "Trump 1", "Biden", "Trump 2"))) |>
  arrange(us_admin) |>
  pivot_wider(names_from = actor, values_from = mean_share)

write_csv(tab, "output/table_mean_share_by_admin.csv")
print(tab)
