# Production readiness — HOLD

**Decision: DO NOT RELEASE OR COPY THIS PACKAGE TO THE LIVE APP.** The current draft has 27 banks / 677 questions; it is not a production-approved course. The structural validator currently passes, but that is necessary and not sufficient.

## Release-gate status

| Gate | Status | Evidence / required action |
|---|---|---|
| JSON/schema, five-choice answer arrays, answer-index range, no question-level `topic`/`subject`, duplicate exact stems | **PASS — structural only** | Run `python3 content_base_patch/scripts/validate_revision_banks.py`. This checks shape, not whether the marked answer is correct. |
| Mapping references and bank-file inventory | **PASS — structural only** | The draft overlay should map every bank once. The validator checks missing, duplicate, unsafe and unreferenced paths. |
| Official TRE-4 syllabus and exam-rule verification | **BLOCKED** | The official Advertisement 15/2026 PDF could not be retrieved/parsed in the earlier audit. The readable third-party transcription has an internal duration conflict. Obtain and review the official notice and applicable corrigenda before asserting exact TRE-4 coverage or pattern. |
| Primary March 2024 booklet topic review | **BLOCKED** | The supplied Primary booklet is image-only in the current audit; OCR/rendered page-by-page review was not completed. Do not claim Primary paper-topic coverage from it. |
| Grade- and unit-level coverage for the approved Classes 1–10 scope | **FAIL / INCOMPLETE** | `COVERAGE_MATRIX.md` identifies mixed-level General Studies/science banks, a combined Classes 6–10 Mathematics bank, and missing per-unit crosswalks. Twenty-five questions in a broad subject bank do not equal 25 per syllabus unit. |
| Subject-matter and answer-key review | **NOT DONE** | No independent teacher/subject-expert sign-off is recorded for these original practice questions or their answer keys. Review every item before charging users. |
| Hindi/English language review | **NOT DONE** | Bilingual display fields and structure pass; translations, grammar, age-level suitability and explanations have not received independent editorial QA. |
| Urdu/Bengali native-language review | **BLOCKED** | Provisional banks exist, but require native-language review, including script, transliteration, vocabulary, grammar and answer keys. |
| App visibility / Language hub | **BLOCKED** | The current Revision UI does not consume the proposed `language_mapping` or expose a Language hub. Do not assume those banks will be reachable in the app. App changes have not been authorized or made in this content-only package. |
| Social Science choice rule in app | **NOT VERIFIED** | The rule is documented (choose two; History or Geography mandatory), but no end-to-end app enforcement test is recorded. |
| Production integration and smoke test | **NOT DONE** | The overlay has not been merged into the live Content Base or tested in an installed build. Do not infer runtime compatibility from JSON validation. |

## Minimum release blockers

1. Resolve the official TRE-4 source and version conflicts; keep any provisional source claims clearly labelled.
2. Complete a class-band and syllabus-unit crosswalk for every approved section, using reviewed source material. Add sufficient original practice to every unit—not merely every subject file.
3. Obtain independent subject-matter answer-key and bilingual editorial review. Urdu/Bengali additionally need native-language review.
4. Resolve the Language-hub/app-visibility gap and verify the Social Science selection rule in the installed app, with explicit authorization for any app changes.
5. Re-run structural validation, review the final diff, merge only the approved mapping additions, then smoke-test the exact release build.

Until each applicable gate is signed off, retain the DRAFT warning in `README.md` and do not copy this package live or market it as complete.
