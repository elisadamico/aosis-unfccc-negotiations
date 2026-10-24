# Codebook

Variables in the files in `data/clean/`. For how the source data was coded,
see the original codebook by Castro et al., which comes with the raw download.

## `meetings.csv`

One row per meeting (96 meetings, 1995–2025).

| Variable | Meaning |
|---|---|
| `meeting_id` | Number for each meeting, in date order |
| `meeting` | Meeting name as given in the ENB |
| `meeting_type` | `COP`, `intersessional` (subsidiary body sessions and other negotiating rounds, mostly in Bonn), or `other` (events that are not negotiations, such as regional climate weeks) |
| `cop_number` | COP number for COPs. COP6 met twice, so the second part is `6 (resumed)` |
| `year` | Year the meeting started |
| `start_date`, `end_date` | First and last day of the meeting |
| `location` | City and country |
| `us_admin` | US administration on the first day of the meeting: Clinton, Bush, Obama, Trump 1, Biden, Trump 2 |
| `us_paris_status` | US position on the Paris Agreement on the first day of the meeting (see below) |
| `n_daily_issues` | Number of daily ENB reports for the meeting |
| `note` | Notes on the meeting, where useful |

The US Paris status uses these dates.

| Status | From | Until |
|---|---|---|
| `pre-Paris` | start of data | 11 Dec 2015 (Paris Agreement adopted 12 Dec 2015) |
| `in` | 12 Dec 2015 | 31 May 2017 |
| `withdrawal announced` | 1 Jun 2017 (first withdrawal announced) | 3 Nov 2020 |
| `withdrawn` | 4 Nov 2020 (withdrawal takes effect) | 18 Feb 2021 |
| `in` | 19 Feb 2021 (US rejoins) | 19 Jan 2025 |
| `withdrawal announced` | 20 Jan 2025 (second withdrawal announced, notified 27 Jan 2025) | 26 Jan 2026 |
| `withdrawn` | 27 Jan 2026 (takes effect) | (no meetings in the data yet) |

## `panel_meeting_actor.csv`

One row per actor per meeting. Every actor appears at every meeting, with zeros
where it was not reported. Meeting variables (`meeting_id` to `us_paris_status`)
are repeated from `meetings.csv` for convenience.

Actors are every coalition in the source (AOSIS, EU, LDCs, G-77/China, BASIC,
LMDCs, Umbrella Group (`UG`), African Group, and others), the `United States`,
and `AOSIS members (individually)`, which pools the 39 AOSIS member states
speaking in their own name (listed in `aosis_members.txt`).

| Variable | Meaning |
|---|---|
| `actor` | The coalition or country |
| `suggested_comparison` | `TRUE` for AOSIS, AOSIS members (individually), EU, LDCs, G-77/China and the United States |
| `n_interventions` | Times the actor is reported speaking at the meeting |
| `n_interventions_all` | Times anyone (any country or group) is reported speaking at the meeting |
| `share_interventions` | `n_interventions / n_interventions_all`. The actor's share of everything said. Use this, not raw counts, to compare over time |
| `n_mitigation`, `n_adaptation`, `n_loss_and_damage`, `n_finance`, `n_science` | Interventions by the actor in negotiations on that topic. Topics come from the source and can overlap |
| `share_mitigation` … `share_science` | Actor's share of all interventions on that topic at the meeting. Empty when nobody spoke on that topic |
| `support_received` | Times another actor is reported supporting this actor |
| `opposition_received` | Times another actor is reported opposing this actor |
| `us_support_received`, `us_opposition_received` | The same, counting only the United States as the other actor |
| `support_given`, `opposition_given` | Times this actor is reported supporting or opposing another actor |
| `agreement_ties` | Times this actor is reported taking the same position as another actor |
| `n_mitigation_all` … `n_science_all` | Interventions by anyone on that topic at the meeting (denominators for the topic shares) |

Interactions between two AOSIS member states acting individually also count
toward `AOSIS members (individually)`.

## `aosis_sentences.csv`

One row per ENB sentence in which AOSIS as a group or one of its member states
is reported speaking. The same sentence can appear more than once if several
AOSIS members are named in it.

| Variable | Meaning |
|---|---|
| `meeting_id` … `us_paris_status` | Meeting information, as above |
| `date` | Date of the ENB report |
| `speaker` | `AOSIS (group)`, or the name of the member state |
| `negotiation_body` | UNFCCC body where it was said (COP, CMA, SBI, SBSTA, APA, and so on). See the source codebook |
| `heading` | ENB section heading, which usually names the agenda item |
| `sentence` | The ENB sentence |
| `mitigation` … `other_unknown` | 1 if the negotiation was on that topic, from the source |

## `aosis_interactions.csv`

One row per interaction between AOSIS (as a group) and another actor.

| Variable | Meaning |
|---|---|
| `meeting_id` … `us_paris_status` | Meeting information, as above |
| `date` | Date of the ENB report |
| `type` | `agreement`, `support`, `opposition` or `on-behalf` |
| `direction` | `AOSIS -> counterpart` (AOSIS supports or opposes the other actor), `counterpart -> AOSIS` (the other actor supports or opposes AOSIS), or `mutual` (agreement) |
| `counterpart` | The other actor. `<Others>` is the source's label for unnamed "others" in a sentence |
| `counterpart_is_aosis_member` | `TRUE` if the counterpart is an AOSIS member state |
| `negotiation_body`, `heading`, `sentence`, topic columns | As in `aosis_sentences.csv` |
