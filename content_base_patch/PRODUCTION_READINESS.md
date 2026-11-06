# Production readiness — HOLD

**Decision: DO NOT RELEASE OR COPY THIS PACKAGE TO THE LIVE APP.** The current draft has 27 banks / 677 questions; it is not a production-approved course. The structural validator passes, but that is necessary and not sufficient.

## Official source review — partial, not final

The user supplied `BPSC_TRE_4_NOTIFICATION_2026.pdf`. Its first page identifies it as BPSC Advertisement 14/2026, dated 18 August 2026, and states 32,388 vacancies. The five-page `BPSC-School-Teacher-TRE-4.0-Syllabus-Exam-Pattern-2026.pdf` is an exact text match for printed pages 13–17 of that notice. Those pages were visually reviewed.

Advertisement 14/2026 confirms, at a high level:

- A separate Preliminary General Studies exam: 150 questions / 150 marks, two hours, with one-third negative marking; it lists broad GS areas, not a class-by-class chapter map.
- Main papers: 150 questions / 150 marks. **The notice conflicts with itself on duration:** the class-wise table on printed page 14 says 2 hours 30 minutes, while the general Main-exam rule on printed page 16 says 2 hours. Printed page 16 also states one mark per question, one-third negative marking and five A–E choices (E for unanswered). Do not present the Main duration as settled until the later notice/corrigendum resolves it.
- The Main Language section is qualifying (30 questions; 30% minimum). Primary has 120 General Studies questions after Language; Middle and Secondary have 40 General Studies plus 80 questions in the chosen subject paper.
- The Middle/Secondary Social Science rule uses two sections: choose History or Geography in Section I; Section II choices then depend on that selection. This is consistent with the approved “two of four, History or Geography mandatory” rule.
- Subject syllabi refer broadly to SCERT/NCERT and the candidate's prescribed level; these pages do **not** enumerate class- and unit-level coverage.

**Version gap remains:** the supplied notice is Advertisement 14/2026, not the later Advertisement 15/2026 identified in the earlier source audit. The later official application-extension notice reports 33,320 vacancies, versus 32,388 in Advertisement 14/2026. Advertisement 15/2026 and applicable later corrigenda have not yet been read; they must be checked for a duration correction, other pattern changes and the final vacancy/subject information. Do not assume Advertisement 14/2026 is the final version.

## Release-gate status

| Gate | Status | Evidence / required action |
|---|---|---|
| JSON/schema, five-choice answer arrays, answer-index range, no question-level `topic`/`subject`, duplicate exact stems | **PASS — structural only** | Run `python3 content_base_patch/scripts/validate_revision_banks.py`. This checks shape, not whether the marked answer is correct. |
| Mapping references and bank-file inventory | **PASS — structural only** | The draft overlay should map every bank once. The validator checks missing, duplicate, unsafe and unreferenced paths. |
| Current official TRE-4 notice and amendments | **PARTIAL / BLOCKED** | Advertisement 14/2026 is reviewed, but its Main-duration table (2:30) conflicts with its general Main rule (2:00). Obtain/read Advertisement 15/2026 and applicable corrigenda; reconcile this conflict, the 32,388 vs 33,320 vacancy notices, and any syllabus/pattern changes. |
| Preliminary-stage coverage | **SCOPE / COVERAGE GAP** | Advertisement 14/2026 specifies a separate Preliminary GS exam. This draft does not have a separate Prelim source-to-bank/unit map. Confirm whether the package promises Preliminary preparation; if yes, map and fill it separately. |
| Primary March 2024 booklet topic review | **BLOCKED** | `BPSC-TRE-3.0-Primary-Question-Papers-2024-PDFs-March-2024.pdf` remains image-only in this audit; OCR/rendered page-by-page review was not completed. A separate text-extractable Primary booklet is coded 2023 and does not replace the 2024 review. |
| Grade- and unit-level coverage for the approved Classes 1–10 scope | **FAIL / INCOMPLETE** | `COVERAGE_MATRIX.md` identifies mixed-level General Studies/science banks, a combined Classes 6–10 Mathematics bank, and missing per-unit crosswalks. Twenty-five questions in a broad subject bank do not equal 25 per syllabus unit. |
| Subject-matter and answer-key review | **NOT DONE** | No independent teacher/subject-expert sign-off is recorded for these original practice questions or their answer keys. Review every item before charging users. |
| Hindi/English language review | **NOT DONE** | Bilingual display fields and structure pass; translations, grammar, age-level suitability and explanations have not received independent editorial QA. |
| Urdu/Bengali native-language review | **BLOCKED** | Provisional banks exist, but require native-language review, including script, transliteration, vocabulary, grammar and answer keys. |
| App visibility / Language hub | **BLOCKED** | The current Revision UI does not consume the proposed `language_mapping` or expose a Language hub. Do not assume those banks will be reachable in the app. App changes have not been authorized or made in this content-only package. |
| Social Science choice rule in app | **NOT VERIFIED** | The rule is now confirmed in Advertisement 14/2026, but no end-to-end app enforcement test is recorded. |
| Production integration and smoke test | **NOT DONE** | The overlay has not been merged into the live Content Base or tested in an installed build. Do not infer runtime compatibility from JSON validation. |

## Minimum release blockers

1. Read and reconcile the latest official Advertisement 15/2026 and all applicable corrigenda against the supplied Advertisement 14/2026, explicitly resolving the 2:00 vs 2:30 Main-duration conflict.
2. Confirm whether this package includes the separate Preliminary GS stage. If it does, add a distinct stage/unit crosswalk and sufficient mapped practice.
3. Complete a class-band and syllabus-unit crosswalk for every approved Main-paper section, using reviewed source material. Add sufficient original practice to every unit—not merely every subject file.
4. Complete the Primary 2024 booklet review and obtain independent subject-matter answer-key and bilingual editorial review. Urdu/Bengali additionally need native-language review.
5. Resolve the Language-hub/app-visibility gap and verify the Social Science selection rule in the installed app, with explicit authorization for any app changes.
6. Re-run structural validation, review the final diff, merge only the approved mapping additions, then smoke-test the exact release build.

Until each applicable gate is signed off, retain the DRAFT warning in `README.md` and do not copy this package live or market it as complete.
