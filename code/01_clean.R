# =============================================================================
# 01_clean.R
# Turns the raw ENB negotiation data (Castro et al., v2.0) into clean files
# for studying AOSIS in the UNFCCC negotiations, 1995-2025.
#
# Input : data/raw/swissubase_2719_2_0/   (download from SWISSUbase, see README)
#         data/meetings_lookup.csv        (hand-made: which meetings are COPs)
# Output: data/clean/meetings.csv
#         data/clean/panel_meeting_actor.csv
#         data/clean/aosis_sentences.csv
#         data/clean/aosis_interactions.csv
#         data/clean/aosis_members.txt
#
# Run from the project root (open aosis-unfccc-negotiations.Rproj in RStudio,
# then source this file). Takes under a minute.
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
})

raw_dir   <- "data/raw/swissubase_2719_2_0"
clean_dir <- "data/clean"
dir.create(clean_dir, showWarnings = FALSE, recursive = TRUE)

raw_csv <- function(name) {
  file.path(raw_dir, paste0("2719_UN_ClimateNegotiations_Data_", name, "_v2.0.csv"))
}
raw_txt <- function(name) {
  file.path(raw_dir, paste0("2719_UN_ClimateNegotiations_Data_", name, "_v2.0.txt"))
}

# The raw CSVs wrap many text fields in single quotes ('...'). Remove them.
strip_quotes <- function(x) str_remove_all(x, "^'|'$")

topic_cols <- c("mitigation", "markets", "aviation_maritime", "forests", "agriculture",
                "adaptation", "loss_and_damage", "response_measures", "finance",
                "capacity_building", "technology_transfer", "reporting_and_review",
                "compliance", "science", "arrangements_meetings",
                "institutional_procedures", "organisation", "country_specific",
                "social_issues", "legal_issues", "new_instrument", "plenaries",
                "other_unknown")

# Topics that get their own columns in the panel (the ones closest to AOSIS's agenda)
panel_topics <- c("mitigation", "adaptation", "loss_and_damage", "finance", "science")


# -----------------------------------------------------------------------------
# Step 1. Meetings
# One row per negotiation meeting, with dates, COP number and US context.
# -----------------------------------------------------------------------------

issues <- read_csv(raw_csv("Issues"), show_col_types = FALSE,
                   col_types = cols(.default = "c")) |>
  rename(issue_id = id, issue_type = type)

lookup <- read_csv("data/meetings_lookup.csv", show_col_types = FALSE,
                   col_types = cols(.default = "c"))

# meeting_date comes in three formats:
#   "29 November 2010 - 11 December 2010"   "1-11 June 2015"   "12.Dec.20"
parse_start_end <- function(x) {
  x <- str_squish(x)
  out <- tibble(start_date = as.Date(NA), end_date = as.Date(NA), .rows = length(x))

  full <- str_detect(x, "^\\d{1,2} \\w+ \\d{4} - \\d{1,2} \\w+ \\d{4}$")
  parts <- str_split_fixed(x[full], " - ", 2)
  out$start_date[full] <- dmy(parts[, 1])
  out$end_date[full]   <- dmy(parts[, 2])

  short <- str_detect(x, "^\\d{1,2}-\\d{1,2} \\w+ \\d{4}$")
  m <- str_match(x[short], "^(\\d{1,2})-(\\d{1,2}) (\\w+ \\d{4})$")
  out$start_date[short] <- dmy(paste(m[, 2], m[, 4]))
  out$end_date[short]   <- dmy(paste(m[, 3], m[, 4]))

  single <- str_detect(x, "^\\d{1,2}\\.\\w{3}\\.\\d{2}$")
  out$start_date[single] <- dmy(x[single])
  out$end_date[single]   <- dmy(x[single])

  out
}

# Which US administration was in office, and where the US stood on Paris,
# on the first day of each meeting.
#   Withdrawal 1: announced 1 Jun 2017, effective 4 Nov 2020, rejoined 19 Feb 2021
#   Withdrawal 2: announced 20 Jan 2025, notified 27 Jan 2025, effective 27 Jan 2026
us_admin <- function(d) {
  case_when(
    d < ymd("2001-01-20") ~ "Clinton",
    d < ymd("2009-01-20") ~ "Bush",
    d < ymd("2017-01-20") ~ "Obama",
    d < ymd("2021-01-20") ~ "Trump 1",
    d < ymd("2025-01-20") ~ "Biden",
    TRUE                  ~ "Trump 2"
  )
}
us_paris_status <- function(d) {
  case_when(
    d < ymd("2015-12-12") ~ "pre-Paris",
    d < ymd("2017-06-01") ~ "in",
    d < ymd("2020-11-04") ~ "withdrawal announced",
    d < ymd("2021-02-19") ~ "withdrawn",
    d < ymd("2025-01-20") ~ "in",
    d < ymd("2026-01-27") ~ "withdrawal announced",
    TRUE                  ~ "withdrawn"
  )
}

meetings <- issues |>
  group_by(meeting) |>
  summarise(meeting_date   = first(meeting_date),
            location       = first(location),
            n_daily_issues = sum(issue_type == "issue"),
            .groups = "drop") |>
  left_join(lookup, by = "meeting")

meetings <- bind_cols(meetings, parse_start_end(meetings$meeting_date)) |>
  mutate(
    year            = year(start_date),
    us_admin        = us_admin(start_date),
    us_paris_status = us_paris_status(start_date),
    # one location is mislabelled in the source
    location        = if_else(meeting == "Bonn Climate Change Talks - August 2010",
                              "Bonn, Germany", location)
  ) |>
  arrange(start_date) |>
  mutate(meeting_id = row_number())

stopifnot(!anyNA(meetings$start_date), !anyNA(meetings$meeting_type))

# Following the codebook's advice: drop curtain-raisers (they describe the
# run-up, not the meeting) and drop the end-of-meeting summary whenever the
# meeting also has daily issues (otherwise the last day is counted twice).
keep_issues <- issues |>
  left_join(select(meetings, meeting, meeting_id, n_daily_issues), by = "meeting") |>
  filter(issue_type != "curtain-raiser",
         !(issue_type == "summary" & n_daily_issues > 0)) |>
  select(issue_id, meeting_id)

meetings <- meetings |>
  mutate(meeting = str_squish(meeting)) |>
  select(meeting_id, meeting, meeting_type, cop_number, year, start_date, end_date,
         location, us_admin, us_paris_status, n_daily_issues, note)


# -----------------------------------------------------------------------------
# Step 2. Actors
# All coalitions in the source, plus the United States, plus one constructed
# actor, "AOSIS members (individually)": AOSIS member states speaking in their
# own name. Membership is taken from the source's Parties file.
# -----------------------------------------------------------------------------

groupings <- read_lines(raw_txt("CountryGroupings")) |>
  str_remove(":.*$") |>
  str_squish()
groupings <- groupings[groupings != ""]

parties <- read_lines(raw_txt("Parties"))
aosis_members <- parties[str_detect(parties, "\\[[^]]*\\bAOSIS\\b")] |>
  str_remove("[:\\[].*$") |>
  str_squish()

aosis_ind <- "AOSIS members (individually)"
actors    <- c(groupings, "United States", aosis_ind)

to_actor <- function(entity) if_else(entity %in% aosis_members, aosis_ind, entity)


# -----------------------------------------------------------------------------
# Step 3. Interventions and interactions, attached to meetings
# -----------------------------------------------------------------------------

interventions <- read_csv(raw_csv("Interventions_wtopics"), show_col_types = FALSE,
                          col_types = cols(.default = "c")) |>
  mutate(across(c(entity, date, heading, sentence, heading_clean, neg_group), strip_quotes),
         across(all_of(topic_cols), as.integer),
         actor = to_actor(entity)) |>
  inner_join(keep_issues, by = "issue_id")

interactions <- read_csv(raw_csv("Interactions_wtopics"), show_col_types = FALSE,
                         col_types = cols(.default = "c")) |>
  mutate(across(c(entity_a, entity_b, type, date, heading, sentence, heading_clean,
                  neg_group), strip_quotes),
         across(all_of(topic_cols), as.integer),
         actor_a = to_actor(entity_a),
         actor_b = to_actor(entity_b)) |>
  inner_join(keep_issues, by = "issue_id")


# -----------------------------------------------------------------------------
# Step 4. Panel: one row per meeting x actor
# Counts are turned into shares of everything said at that meeting, because
# the amount of ENB text per meeting varies a lot over time.
# -----------------------------------------------------------------------------

grid <- expand_grid(meeting_id = meetings$meeting_id, actor = actors)

# Totals per meeting (all entities, countries and groups), overall and by topic
totals <- interventions |>
  group_by(meeting_id) |>
  summarise(n_interventions_all = n(),
            across(all_of(panel_topics), ~ sum(.x == 1), .names = "n_{.col}_all"),
            .groups = "drop")

speaking <- interventions |>
  filter(actor %in% actors) |>
  group_by(meeting_id, actor) |>
  summarise(n_interventions = n(),
            across(all_of(panel_topics), ~ sum(.x == 1), .names = "n_{.col}"),
            .groups = "drop")

# Directed interactions: A -> B. "Given" counts A's acts, "received" counts B's.
directed <- interactions |> filter(type %in% c("support", "opposition"))

given <- directed |>
  count(meeting_id, actor = actor_a, type) |>
  pivot_wider(names_from = type, values_from = n, values_fill = 0,
              names_glue = "{type}_given")
received <- directed |>
  count(meeting_id, actor = actor_b, type) |>
  pivot_wider(names_from = type, values_from = n, values_fill = 0,
              names_glue = "{type}_received")
from_us <- directed |>
  filter(actor_a == "United States") |>
  count(meeting_id, actor = actor_b, type) |>
  pivot_wider(names_from = type, values_from = n, values_fill = 0,
              names_glue = "us_{type}_received")

# Agreement is stored twice in the source (A -> B and B -> A), so counting
# rows by entity_a alone gives each tie once per actor
agreement <- interactions |>
  filter(type == "agreement") |>
  count(meeting_id, actor = actor_a, name = "agreement_ties")

panel <- grid |>
  left_join(speaking,  by = c("meeting_id", "actor")) |>
  left_join(given,     by = c("meeting_id", "actor")) |>
  left_join(received,  by = c("meeting_id", "actor")) |>
  left_join(from_us,   by = c("meeting_id", "actor")) |>
  left_join(agreement, by = c("meeting_id", "actor")) |>
  mutate(across(where(is.numeric) & !meeting_id, ~ replace_na(.x, 0))) |>
  left_join(totals, by = "meeting_id") |>
  mutate(n_interventions_all = replace_na(n_interventions_all, 0),
         share_interventions = if_else(n_interventions_all > 0,
                                       n_interventions / n_interventions_all, NA_real_))

for (t in panel_topics) {
  panel[[paste0("share_", t)]] <- if_else(panel[[paste0("n_", t, "_all")]] > 0,
                                          panel[[paste0("n_", t)]] / panel[[paste0("n_", t, "_all")]],
                                          NA_real_)
}

for (col in c("support_given", "opposition_given", "support_received", "opposition_received",
              "us_support_received", "us_opposition_received")) {
  if (!col %in% names(panel)) panel[[col]] <- 0L
}

panel <- meetings |>
  select(meeting_id, meeting, meeting_type, cop_number, year, start_date,
         us_admin, us_paris_status) |>
  right_join(panel, by = "meeting_id") |>
  mutate(suggested_comparison = actor %in% c("AOSIS", "EU", "LDCs", "G-77/China",
                                             "United States", aosis_ind)) |>
  select(meeting_id, meeting, meeting_type, cop_number, year, start_date,
         us_admin, us_paris_status, actor, suggested_comparison,
         n_interventions, n_interventions_all, share_interventions,
         starts_with("n_") & !c(n_interventions, n_interventions_all) & !ends_with("_all"),
         starts_with("share_") & !share_interventions,
         support_received, opposition_received, us_support_received, us_opposition_received,
         support_given, opposition_given, agreement_ties,
         ends_with("_all") & !n_interventions_all) |>
  arrange(start_date, actor)


# -----------------------------------------------------------------------------
# Step 5. AOSIS sentences, for close reading
# Every sentence where AOSIS (as a group) or an AOSIS member speaks.
# -----------------------------------------------------------------------------

aosis_sentences <- interventions |>
  filter(actor %in% c("AOSIS", aosis_ind)) |>
  left_join(select(meetings, meeting_id, meeting, meeting_type, cop_number, year,
                   us_admin, us_paris_status), by = "meeting_id") |>
  mutate(speaker = if_else(entity == "AOSIS", "AOSIS (group)", entity)) |>
  select(meeting_id, meeting, meeting_type, cop_number, year, us_admin, us_paris_status,
         date, speaker, negotiation_body = neg_group, heading = heading_clean, sentence,
         all_of(topic_cols)) |>
  arrange(meeting_id, date)


# -----------------------------------------------------------------------------
# Step 6. AOSIS interactions
# Every support / opposition / agreement / on-behalf tie involving AOSIS as a
# group, written from AOSIS's point of view.
# -----------------------------------------------------------------------------

aosis_interactions <- interactions |>
  filter(entity_a == "AOSIS" | entity_b == "AOSIS") |>
  # keep one copy of each (double-stored) agreement
  filter(!(type == "agreement" & entity_b == "AOSIS")) |>
  mutate(
    counterpart = if_else(entity_a == "AOSIS", entity_b, entity_a),
    direction = case_when(
      type == "agreement"  ~ "mutual",
      entity_a == "AOSIS"  ~ "AOSIS -> counterpart",
      TRUE                 ~ "counterpart -> AOSIS"
    ),
    counterpart_is_aosis_member = counterpart %in% aosis_members
  ) |>
  left_join(select(meetings, meeting_id, meeting, meeting_type, cop_number, year,
                   us_admin, us_paris_status), by = "meeting_id") |>
  select(meeting_id, meeting, meeting_type, cop_number, year, us_admin, us_paris_status,
         date, type, direction, counterpart, counterpart_is_aosis_member,
         negotiation_body = neg_group, heading = heading_clean, sentence,
         all_of(topic_cols)) |>
  arrange(meeting_id, date)


# -----------------------------------------------------------------------------
# Step 7. Write out
# -----------------------------------------------------------------------------

write_csv(meetings,           file.path(clean_dir, "meetings.csv"), na = "")
write_csv(panel,              file.path(clean_dir, "panel_meeting_actor.csv"), na = "")
write_csv(aosis_sentences,    file.path(clean_dir, "aosis_sentences.csv"), na = "")
write_csv(aosis_interactions, file.path(clean_dir, "aosis_interactions.csv"), na = "")
write_lines(aosis_members,    file.path(clean_dir, "aosis_members.txt"))

message("Done. Meetings: ", nrow(meetings),
        " | panel rows: ", nrow(panel),
        " | AOSIS sentences: ", nrow(aosis_sentences),
        " | AOSIS interactions: ", nrow(aosis_interactions))
