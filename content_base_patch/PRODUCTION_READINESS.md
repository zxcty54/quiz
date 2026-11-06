# Production readiness — HOLD

**Decision: DO NOT RELEASE OR COPY THIS PACKAGE TO THE LIVE APP.** The current draft has 27 banks / 677 questions; it is not a production-approved course. The structural validator passes, but that is necessary and not sufficient.

## Current official source review

The user supplied `Advertisement-152026-TRE-4.0_BPSC-20260922-dbsf04.pdf`, a 24-page scanned BPSC Advertisement 15/2026 dated 22 September 2026. Its first page explicitly cancels Advertisement 14/2026 and states 32,388 vacancies. The scan has no extractable text layer; pages 1 and 13–16 were rendered and visually reviewed.

Advertisement 15/2026 confirms, at a high level:

- Selection is based on an objective written examination. The canceled Advertisement 14/2026's separate Preliminary/Main scheme is superseded; Advertisement 15/2026 does not list a separate Preliminary stage.
- The class-wise Main-paper table on printed pages 13–14 specifies 150 questions / 150 marks and 2 hours 30 minutes. Part I is 30 qualifying Language questions (minimum 30%); Primary has 120 General Studies questions, while Middle and Secondary have 40 General Studies plus 80 questions in the chosen subject paper.
- Part II topic headings differ by band. Primary names elementary mathematics, mental ability, general awareness, general science, social science, the Indian national movement, geography and environment. Middle/Secondary name elementary mathematics, general awareness, general science, the Indian national movement and geography. Middle Part III combines Mathematics and Science as one subject-paper option; Social Science is also a structured subject paper.
- Printed page 15 specifies one-third negative marking, five choices A–E, and E for unanswered. The Middle/Secondary Social Science rule uses two sections: choose History or Geography in Section I; Section II options then depend on that selection. This matches the approved “two of four, History or Geography mandatory” rule.
- The notice refers to SCERT/NCERT and the candidate's prescribed level, but it does **not** enumerate class-by-class chapters, units or question weights. It establishes paper structure, not exhaustive syllabus coverage.

**Working content policy from the user's direction:** use every relevant chapter in the latest Bihar SCERT books for the approved classes/subjects as the coverage checklist, with NCERT as a cross-check or supplement where SCERT coverage is missing. This is a conservative product-completeness policy—not a claim that BPSC officially mandates every page/chapter.

The earlier Advertisement 14/2026 upload and its five-page extract are superseded; their Preliminary-stage language and internal duration conflict should not be used as the current exam pattern. A later official application-extension notice identified in the earlier audit reports 33,320 vacancies versus Advertisement 15/2026's 32,388. That vacancy discrepancy needs current administrative verification, but does not itself supply a different syllabus. Check any post-Advertisement-15 corrigenda before release.

## Release-gate status

| Gate | Status | Evidence / required action |
|---|---|---|
| JSON/schema, five-choice answer arrays, answer-index range, no question-level `topic`/`subject`, duplicate exact stems | **PASS — structural only** | Run `python3 content_base_patch/scripts/validate_revision_banks.py`. This checks shape, not whether the marked answer is correct. |
| Mapping references and bank-file inventory | **PASS — structural only** | The draft overlay should map every bank once. The validator checks missing, duplicate, unsafe and unreferenced paths. |
| Advertisement 15/2026 exam-pattern verification | **PASS — high-level only** | Scanned pages 1 and 13–16 were reviewed. The 150-question / 2.5-hour pattern, section split, marking and Social Science rule are clear in this notice. Check later corrigenda before release. |
| SCERT/NCERT book corpus and edition inventory | **BLOCKED — inputs missing** | The uploaded files are notices and past papers; no Class 1–10 textbook PDFs, chapter lists or edition/year manifest were supplied. Provide the latest relevant Bihar SCERT books/contents or exact book titles and editions before a reliable full-book crosswalk can be built. |
| Class- and unit-level coverage for the approved Classes 1–10 scope | **FAIL / INCOMPLETE** | `COVERAGE_MATRIX.md` identifies mixed-level General Studies/science banks, a combined Classes 6–10 Mathematics bank, and missing per-unit crosswalks. The notice is broad and does not provide a chapter-by-chapter syllabus. Twenty-five questions in a broad subject bank do not equal 25 per syllabus unit. |
| Primary March 2024 booklet topic review | **BLOCKED** | `BPSC-TRE-3.0-Primary-Question-Papers-2024-PDFs-March-2024.pdf` remains image-only in this audit; OCR/rendered page-by-page review was not completed. A separate text-extractable Primary booklet is coded 2023 and does not replace the 2024 review. |
| Subject-matter and answer-key review | **NOT DONE** | No independent teacher/subject-expert sign-off is recorded for these original practice questions or their answer keys. Review every item before charging users. |
| Hindi/English language review | **NOT DONE** | Bilingual display fields and structure pass; translations, grammar, age-level suitability and explanations have not received independent editorial QA. |
| Urdu/Bengali native-language review | **BLOCKED** | Provisional banks exist, but require native-language review, including script, transliteration, vocabulary, grammar and answer keys. |
| App visibility / Language hub | **BLOCKED** | The current Revision UI does not consume the proposed `language_mapping` or expose a Language hub. Do not assume those banks will be reachable in the app. App changes have not been authorized or made in this content-only package. |
| Social Science choice rule in app | **NOT VERIFIED** | The rule is confirmed in Advertisement 15/2026, but no end-to-end app enforcement test is recorded. |
| Production integration and smoke test | **NOT DONE** | The overlay has not been merged into the live Content Base or tested in an installed build. Do not infer runtime compatibility from JSON validation. |

## Minimum release blockers

1. Establish the exact latest Bihar SCERT books/editions for each approved class and subject (with NCERT used only as a recorded cross-check/supplement), then build the class-band/chapter crosswalk. Add sufficient original practice to every unit—not merely every subject file.
2. Complete the Primary 2024 booklet review and obtain independent subject-matter answer-key and bilingual editorial review. Urdu/Bengali additionally need native-language review.
3. Confirm no post-Advertisement-15 corrigendum changes the paper structure or approved subject scope; verify the latest administrative vacancy notice separately if the app displays vacancy data.
4. Resolve the Language-hub/app-visibility gap and verify the Social Science selection rule in the installed app, with explicit authorization for any app changes.
5. Re-run structural validation, review the final diff, merge only the approved mapping additions, then smoke-test the exact release build.

Until each applicable gate is signed off, retain the DRAFT warning in `README.md` and do not copy this package live or market it as complete.
