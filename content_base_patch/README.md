# DRAFT — INCOMPLETE — DO NOT COPY TO THE LIVE APP

This package is **not release-ready**. It currently contains 27 Revision banks / 827 questions. Source-based additions include 25 Class 9 Economics questions from a readable Chapter 1 excerpt, 25 Political Science questions from a readable Chapter 1 excerpt, and 100 additional Political Science questions drafted from user-provided Chapters 1–3 and only the supplied portion of Chapter 4 through voter ID. The exact book/edition for the pasted text remains unverified, and this does not exhaust the BPSC TRE syllabus for Classes 1–10. Keep it on the Arena branch for review and expansion; do not merge or copy it into the live Content Base yet.

The user-approved scope is Primary Language + GS; Middle Language + GS + English, Hindi, Sanskrit, Mathematics, Science, History, Geography, Economics and Political Science; and Secondary Language + GS + English, Mathematics and the four Social Science choice banks. See the release gate at the end of `COVERAGE_MATRIX.md`.

## Release gate before copying

**Production status: HOLD — do not release.** See `PRODUCTION_READINESS.md` for the gate-by-gate blockers. Do not publish this content until all applicable class/subject/unit rows in `COVERAGE_MATRIX.md` have complete mapped coverage, the official-source gaps are resolved or explicitly accepted, independent subject/language review is complete, the app integration gaps are addressed, and final validation and smoke tests pass. The existing `subject_mapping_additions.json` is a draft overlay, not approval to enable these banks.

Run the structural-only validator with:

```bash
python3 content_base_patch/scripts/validate_revision_banks.py
```

A pass checks JSON shape and mapping integrity only; it does **not** certify answer accuracy, translations, syllabus coverage, expert review, or app integration.

## Planned integration after completion and approval

1. Copy `content_base_patch/revision/` into the root of the Content Base repository, preserving relative paths.
2. Merge—not replace—the entries in `subject_mapping_additions.json` into the existing `subject_mapping.json`.
3. The current Revision screen has no Language hub. Language banks (including provisional Urdu/Bengali banks requiring native review) will remain inaccessible until app-side Language support is added; no Flutter/app code has been changed in this package.

## Current JSON format

Each bank is an array of records using the Revision model's supported keys: `qe`, `qh`, `o`, `oe`, `oh`, `a`, `e`, and `eh`. `o`/`oe` contain English choices and `oh` contains Hindi choices; `a` is a zero-based integer from 0 to 4. Each question has five choices. `o` is retained for compatibility with older Content Base readers. The bank records contain no per-question `topic` or `subject` tags. Questions and explanations are original practice, not copied PYQ text.

## Source-confidence warning

The user supplied the scanned BPSC Advertisement 15/2026 (22 September 2026). Its first page cancels Advertisement 14/2026; printed pages 1 and 13–16 were visually reviewed. It confirms the objective written-paper pattern (150 questions/marks, 2.5 hours), qualifying Language and subject sections, and the Social Science choice rule; it does not provide a class-by-class unit syllabus. Do not use the canceled Advertisement 14/2026's separate Preliminary stage or duration conflict as the current pattern. The working coverage assumption is every relevant chapter in the latest Bihar SCERT books for approved classes/subjects, with NCERT as a recorded cross-check/supplement. Drive search on 2026-11-07 found Bihar-named textbook files for Classes 5–9, but exact editions and full subject coverage are unverified; no `bihar10` file was found. Readable Drive text from Class 9 Economics Chapter 1 and Political Science Chapter 1 was used for 25 questions in each bank. The user later supplied Political Science text for Chapters 1–3 and part of Chapter 4 through voter ID, from which 100 additional original questions were drafted (25 per chapter/excerpt); the source title, edition and official status remain unverified. Several other sampled books are no-text scans, over the 25 MB extraction cap, or legacy-font-garbled; the Class 8 Civics DOCX is 84 MB. The complete chapter crosswalk remains blocked. A later official extension notice identified in the earlier audit reports 33,320 vacancies versus 32,388 in Advertisement 15/2026; verify the latest administrative count and any post-advertisement corrigenda. The current 827-question draft does not claim exhaustive TRE-4 coverage. See `PRODUCTION_READINESS.md`.

## Source links

- BPSC Advertisement 15/2026 (official PDF URL listed in BPSC media index): https://bpsc.bihar.gov.in/wp-content/uploads/BPSC_content/Notices/Advertisement-152026-TRE-4.0_BPSC-20260922-dbsf04.pdf
- BPSC application-extension notice (26 October 2026): https://bpsc.bihar.gov.in/wp-content/uploads/BPSC_content/Notices/Image_125_BPSC-20261026-l3wn9q.pdf
- BPSC media index search for TRE-4.0: https://bpsc.bihar.gov.in/wp-json/wp/v2/media?search=TRE-4.0&per_page=100
- BPSC question-booklet archive: https://bpsc.bihar.gov.in/question-booklets/
- Official BPSC exam calendar: https://bpsc.bihar.gov.in/exam-calendar/
- Older third-party TRE syllabus transcription (not BPSC-hosted; superseded for exam pattern by Advertisement 15/2026): https://www.sarkariresult.com/wp-content/uploads/2026/08/bpsc_Syllabus_TRE_SarkariResult.pdf
- Bihar SCERT eResources catalogue: https://scert.bihar.gov.in/eresources/
- Supplied paper filenames and scope limitations are recorded in `COVERAGE_MATRIX.md`.
