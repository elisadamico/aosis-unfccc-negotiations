# AOSIS in the UNFCCC negotiations, 1995–2025

Clean, analysis-ready data on what the Alliance of Small Island States (AOSIS)
said in the UN climate negotiations, who supported or opposed it, and how this
compares with other negotiating groups and with the United States. It covers
every UNFCCC session reported in the Earth Negotiations Bulletin from 1995 to
COP30 in Belém (November 2025), including all thirty COPs.

The data is built from an existing dataset by Castro, Kristof, Kammerer and
Cogne (2025). This repository does not change their coding. It reshapes their
files around one question, namely how AOSIS fared in the talks across US
administrations and the two US withdrawals from the Paris Agreement.

## Where the data comes from

The Earth Negotiations Bulletin (ENB), published by IISD, writes a daily summary
of every UNFCCC meeting. A typical sentence reads "TUVALU, for AOSIS, supported
the 1.5°C goal, opposed by SAUDI ARABIA". Castro et al. scraped every ENB report
since 1995 and used an algorithm to record two things.

- An **intervention** is each time a country or group is reported as speaking.
- An **interaction** is each time one actor agrees with, supports, opposes, or
  speaks on behalf of another.

They checked the algorithm against an older hand-coded dataset. Details are in
their paper (see Citation below) and in their codebook.

## What this repository does

`code/01_clean.R` takes their raw files and does the following, in order.

1. **Labels each meeting.** A hand-made table (`data/meetings_lookup.csv`) marks
   which of the 96 meetings are COPs, which are intersessional negotiating
   sessions (mostly Bonn), and which are other events such as regional climate
   weeks that are not negotiations. COP numbers are added by hand because the
   source names COPs inconsistently (for example "Fiji / Bonn Climate Change
   Conference" for COP23).
2. **Adds US context.** Each meeting gets the US administration in office on its
   first day and the US position on the Paris Agreement at that point (in,
   withdrawal announced, withdrawn). The dates used are listed in the codebook.
3. **Removes double counting**, following the source codebook's advice.
   Curtain-raiser issues (written before a meeting starts) are dropped, and so
   is the end-of-meeting summary whenever the meeting also has daily reports.
4. **Builds actors.** Every coalition in the source is kept, plus the United
   States, plus one constructed actor, "AOSIS members (individually)", which
   pools the 39 AOSIS member states when they speak in their own name. This lets
   you see whether AOSIS speaks as a bloc or its members go it alone.
5. **Turns counts into shares.** The ENB writes far more in some years than
   others (2020 is almost empty because of COVID, and recent COPs are covered
   in much more detail). Raw counts mostly track how much the ENB wrote. The
   panel therefore gives each actor's share of everything said at a meeting,
   overall and within key topics.
6. **Fixes one quirk.** Agreements are stored twice in the source (A agrees with
   B, and B agrees with A). They are counted once here.

`code/02_overview.R` makes three descriptive figures and one table so you can
see the data works. They are a starting point, not findings.

## The files you will use

All in `data/clean/`, each as both an Excel file (`.xlsx`, easiest to open) and
a `.csv` with the same content. Variables are explained in
[`codebook.md`](codebook.md). The Excel files have a frozen header row with
filters, so you can sort and filter by meeting, actor or topic straight away.

| File | One row is | Use it for |
|---|---|---|
| `panel_meeting_actor.csv` | one actor at one meeting | the main quantitative analysis (trends, comparisons across periods) |
| `meetings.csv` | one meeting | dates, COP numbers, US context |
| `aosis_sentences.csv` | one ENB sentence where AOSIS or an AOSIS member speaks | close reading and qualitative coding of what AOSIS asked for |
| `aosis_interactions.csv` | one tie between AOSIS and another actor | who backed AOSIS and who opposed it, with the sentence |
| `aosis_members.txt` | one AOSIS member state | reference |

A good first step is to open `panel_meeting_actor.csv`, keep `meeting_type ==
"COP"` and the suggested comparison actors (`suggested_comparison == TRUE`),
and plot `share_interventions` over time.

## Things to keep in mind

- **The ENB is a summary, not a transcript.** It records what its writers judged
  worth reporting. An actor "speaking less" can mean it was reported less.
- **Share of interventions measures visibility, not success.** It shows how much
  AOSIS was heard, not whether it got what it wanted. Success needs a separate
  measure, such as comparing AOSIS demands (from `aosis_sentences.csv`) with the
  final COP decisions.
- **Support and opposition counts are small.** At most COPs AOSIS receives only a
  handful, so single meetings can swing a lot. Look at periods, not single
  years, and read the sentences behind any spike.
- **The second Trump withdrawal is only partly covered.** The data ends with
  COP30 (November 2025). The withdrawal took legal effect in January 2026.
- **The meeting labels are judgement calls.** They are in a plain CSV so you can
  check or change them.

## How to rerun everything

1. Request the raw data (free, needs a SWISSUbase account) from
   https://doi.org/10.48573/ycjn-zs13 and download version 2.0.
2. Unzip it into `data/raw/` so the files sit in
   `data/raw/swissubase_2719_2_0/`. The raw data is not included in this
   repository.
3. Open `aosis-unfccc-negotiations.Rproj` in RStudio and run
   `source("code/01_clean.R")`, then `source("code/02_overview.R")`.

Packages needed: `readr`, `dplyr`, `tidyr`, `stringr`, `lubridate`, `ggplot2`
(all part of the tidyverse).

## Citation

Please cite the original dataset and paper.

> Castro Pareja, P. M., Kristof, V., Kammerer, M., & Cogne, T. (2025).
> *Participation, Cooperation and Conflict in UN Climate Negotiations*
> (Version 2.0) [Data set]. FORS. https://doi.org/10.48573/ycjn-zs13

> Castro, P., Kristof, V., Kammerer, M., & Cogne, T. (2025). Participation,
> cooperation and conflict in UN climate negotiations. *Scientific Data*, 12,
> 2011. https://doi.org/10.1038/s41597-025-06262-4

The ENB reports are published by the International Institute for Sustainable
Development (IISD), https://enb.iisd.org.

## License

The data in `data/` is derived from the source above and is shared under the
same license, CC BY-NC-SA 4.0. The code in `code/` is under the MIT license. See
[`LICENSE`](LICENSE).
