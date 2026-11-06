# BPSC TRE content coverage and evidence matrix

**Status:** DRAFT — incomplete, not release-ready, and not to be copied into the live app. This is not an exhaustive official TRE-4 chapter map.

**Current starter set:** 25 JSON banks containing 252 original MCQs. Every question has five answer choices and uses the current Revision model's bilingual fields; no per-question topic or subject tags are present. The starter set is not sufficient to claim complete syllabus coverage.

## Scope and evidence

| Area | Evidence reviewed | What it supports | Confidence / limitation |
|---|---|---|---|
| TRE-4 advertisement | BPSC media API lists official Advertisement 15/2026 at the URL in `README.md`; direct PDF retrieval and parsing failed. | Confirms the relevant official notice exists and identifies its URL. | The full advertisement text was not independently verified in this audit. Do not infer detailed syllabus or paper rules from the filename. |
| TRE-4 syllabus | Readable SarkariResult-hosted transcription of a syllabus PDF. It describes Preliminary and Main stages, broad Preliminary GS areas, and class/qualification-level Main subject sections. | Provisional high-level topic selection only. | Third-party transcription, not BPSC-hosted. Its Main exam-duration statements conflict (table says 2:30; another passage says 2:00). Exact TRE-4 chapter and marking details remain unverified. |
| Primary booklet | Supplied `BPSC-Primary-Teacher-Question-Booklet-General-Studies.pdf` (code 21/PV/M–2023). | Booklet pattern: 30 Language + 120 General Studies; five choices A–E. | This is a 2023 booklet, not verified as the TRE-4 pattern. |
| Primary TRE-3 booklet | Supplied `BPSC-TRE-3.0-Primary-Question-Papers-2024-PDFs-March-2024.pdf`. | Evidence that a separate March 2024 Primary paper was supplied. | Image-only; no OCR or page-by-page rendered review was completed. No topic-level claims are taken from it. |
| Middle papers | Supplied Middle English, Hindi, Sanskrit, Math-Science and Social Science booklets dated 19 July 2024. | The reviewed booklets show 150 questions/marks, 2.5 hours, Language 30 + GS 40 + concerned subject 80, and five choices A–E. The common Language section includes English questions E-1–E-8 plus a choice among Hindi/Urdu/Bengali questions 9–30. | These are TRE-3 booklets, not TRE-4 official confirmation. Some legacy-font Hindi/Sanskrit extraction was garbled; do not treat extracted wording as exact source text. |
| Secondary papers | Supplied Secondary English, Maths and Social Science papers dated 21 July 2024. | Same 30 + 40 + 80 section structure and five choices; Social Science has four 40-question subject sections, with any two selected and History or Geography mandatory. | TRE-3 evidence only; not a verified TRE-4 update. |
| Official archive | BPSC question-booklet page was inspected; its PDF widget was unavailable in the fetched page. | Identifies the official archive. | Supplied PDFs are used for pattern review; no inaccessible archive PDF is claimed as a source. |

## Coverage plan for this overlay

The question files are original practice built around the broad Preliminary GS areas, the supplied paper structure, and the level of the supplied Class 1–10 papers. Paths listed below are relative to the Content Base root after copying `content_base_patch/revision/`.

| BPSC area | Content Base files in this patch | Mapping destination | Coverage status |
|---|---|---|---|
| Preliminary / Primary–Secondary General Studies: Indian history, national movement and Bihar context | `revision/general_science/history/bpsc_tre_history_gs.json`; `revision/bihar_special/general/bpsc_tre_bihar_context.json` | `history_mapping`; `bihar_special_mapping` | Static foundation only; not a full chapter-by-chapter syllabus. |
| General Studies: India/Bihar geography and environment | `revision/general_science/geography/bpsc_tre_geography_gs.json`; Bihar questions in `revision/bihar_special/general/bpsc_tre_bihar_context.json` | `geo_mapping`; `bihar_special_mapping` | Selected foundational items; no complete map-work inventory. |
| General Studies: Indian/Bihar economy | `revision/general_science/economy/bpsc_tre_economy_gs.json` | `eco_mapping` | Foundational items; Bihar-specific economic time series and current data are not asserted. |
| General Studies: Indian polity and governance | `revision/general_science/polity/bpsc_tre_polity_gs.json` | `polity_mapping` | Foundational items only. |
| General Science | `revision/general_science/physics/bpsc_tre_physics_gs.json`; `revision/general_science/chemistry/bpsc_tre_chemistry_gs.json`; `revision/general_science/biology/bpsc_tre_biology_gs.json` | `phy_mapping`, `chem_mapping`, `bio_mapping` | Original mixed-level practice; exact TRE-4 grade/topic distribution remains provisional. |
| Mathematics / quantitative practice | `revision/maths/bpsc_tre_primary_math.json`; `revision/maths/bpsc_tre_middle_secondary_math.json` | `aptitude_mapping` | Foundational practice for supplied levels; not every SCERT/NCERT chapter is represented. |
| Mental ability | `revision/reasoningapp/bpsc_tre_mental_ability.json` | `reasoning_mapping` | Selected foundational practice only. |
| Middle / Secondary Social Science choices | `revision/general_science/history/bpsc_tre_middle_history.json`; `.../geography/bpsc_tre_middle_geography.json`; `.../economy/bpsc_tre_middle_economics.json`; `.../polity/bpsc_tre_middle_political_science.json`; corresponding four `bpsc_tre_secondary_*.json` files | `history_mapping`, `geo_mapping`, `eco_mapping`, `polity_mapping` | Separate original practice for all four choices. Paper choice rule remains: choose two; History or Geography must be one. This rule is documented here, not encoded as an in-app lock. |
| Qualifying Language and supplied subject-language papers | `revision/language/english/bpsc_tre_qualifying_english.json`; `revision/language/hindi/bpsc_tre_qualifying_hindi.json`; Middle English/Hindi/Sanskrit and Secondary English files under `revision/language/` | Proposed `language_mapping` only | Content-ready, but the current Revision UI has no Language hub and does not consume a new mapping key. It will not surface until app-side Language support is added. Urdu, Bengali and other language choices are not covered. |
| Dynamic current affairs | No new bank in this overlay | Existing current-affairs content remains independent | Not duplicated here; current-affairs facts need date-stamped updates and separate verification. |

## Important non-claims / remaining work

- This overlay covers Classes 1–10 only. It includes no Classes 11–12 content, Learning lessons, or sectional mocks.
- Question wording is original practice inspired by the broad syllabus and paper structure; it is **not official PYQ text**, and no bank is labelled PYQ.
- The source set does not establish the exact TRE-4 chapter list, chapter weights, current paper duration, negative marking, or every optional subject. Do not claim “complete verified TRE-4 syllabus coverage.”
- Middle Mathematics and Science were combined in the supplied 80-question subject paper; the Revision banks separate their practice for navigation, not as a claim about the official paper's exact allocation.
- Secondary Science, Secondary Hindi/Sanskrit, Urdu/Bengali choices, and other optional subjects were not part of the supplied Secondary booklets reviewed for this build. They are not represented as covered.
- A full source-backed completion pass requires successful review of the official Advertisement 15/2026 PDF, rendered-page review/OCR of the image-only Primary booklet, and official confirmation of any TRE-4 changes to the TRE-3 paper structure.

## Bank inventory

All paths are relative to Content Base root; question counts are confirmed from the generated arrays.

| File | Questions | Intended band / section |
|---|---:|---|
| `revision/general_science/history/bpsc_tre_history_gs.json` | 10 | General Studies, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/geography/bpsc_tre_geography_gs.json` | 10 | General Studies, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/economy/bpsc_tre_economy_gs.json` | 10 | General Studies, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/polity/bpsc_tre_polity_gs.json` | 10 | General Studies, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/physics/bpsc_tre_physics_gs.json` | 10 | General Science, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/chemistry/bpsc_tre_chemistry_gs.json` | 10 | General Science, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/biology/bpsc_tre_biology_gs.json` | 10 | General Science, Classes 1–10 (mixed-level foundation) |
| `revision/bihar_special/general/bpsc_tre_bihar_context.json` | 10 | Bihar context for General Studies, Classes 1–10 |
| `revision/maths/bpsc_tre_primary_math.json` | 10 | Primary General Studies / elementary mathematics, Classes 1–5 |
| `revision/maths/bpsc_tre_middle_secondary_math.json` | 12 | Mathematics foundation, Classes 6–10 |
| `revision/reasoningapp/bpsc_tre_mental_ability.json` | 10 | Mental ability, Classes 1–10 (mixed-level foundation) |
| `revision/general_science/history/bpsc_tre_middle_history.json` | 10 | Middle subject / Social Science History, Classes 6–8 |
| `revision/general_science/geography/bpsc_tre_middle_geography.json` | 10 | Middle subject / Social Science Geography, Classes 6–8 |
| `revision/general_science/economy/bpsc_tre_middle_economics.json` | 10 | Middle subject / Social Science Economics, Classes 6–8 |
| `revision/general_science/polity/bpsc_tre_middle_political_science.json` | 10 | Middle subject / Social Science Political Science, Classes 6–8 |
| `revision/general_science/history/bpsc_tre_secondary_history.json` | 10 | Secondary Social Science History, Classes 9–10 |
| `revision/general_science/geography/bpsc_tre_secondary_geography.json` | 10 | Secondary Social Science Geography, Classes 9–10 |
| `revision/general_science/economy/bpsc_tre_secondary_economics.json` | 10 | Secondary Social Science Economics, Classes 9–10 |
| `revision/general_science/polity/bpsc_tre_secondary_political_science.json` | 10 | Secondary Social Science Political Science, Classes 9–10 |
| `revision/language/english/bpsc_tre_qualifying_english.json` | 10 | Qualifying Language: English, foundational practice |
| `revision/language/hindi/bpsc_tre_qualifying_hindi.json` | 10 | Qualifying Language: Hindi choice, foundational practice |
| `revision/language/english/bpsc_tre_middle_english_subject.json` | 10 | Middle English subject, Classes 6–8 |
| `revision/language/hindi/bpsc_tre_middle_hindi_subject.json` | 10 | Middle Hindi subject, Classes 6–8 |
| `revision/language/sanskrit/bpsc_tre_middle_sanskrit_subject.json` | 10 | Middle Sanskrit subject, Classes 6–8 |
| `revision/language/english/bpsc_tre_secondary_english_subject.json` | 10 | Secondary English subject, Classes 9–10 |

The bank inventory is a **starter set of revision items per mapped area**, not a claim that 10–12 questions exhaust any subject. “Classes 1–10” mixed-level files intentionally avoid an unsupported claim of exact grade-by-grade TRE-4 mapping.
