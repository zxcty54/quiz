# DRAFT — INCOMPLETE — DO NOT COPY TO THE LIVE APP

This package is **not release-ready**. It currently contains only 27 Revision banks / 677 questions (an expanding draft), which do not exhaust the BPSC TRE syllabus for Classes 1–10. Keep it on the Arena branch for review and expansion; do not merge or copy it into the live Content Base yet.

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

The official BPSC Advertisement 15/2026 PDF is listed in BPSC's media index, but its full contents could not be retrieved/parsed during this audit. The readable TRE-4 syllabus transcription is hosted by a third party and contains an internal Main-duration inconsistency. Therefore the current high-level stage/section mapping is provisional; the current 677-question draft does not claim exhaustive or officially verified chapter-level TRE-4 coverage. Re-check the official advertisement and any later BPSC corrigenda before release.

## Source links

- BPSC Advertisement 15/2026 (official PDF URL listed in BPSC media index): https://bpsc.bihar.gov.in/wp-content/uploads/BPSC_content/Notices/Advertisement-152026-TRE-4.0_BPSC-20260922-dbsf04.pdf
- BPSC media index search for TRE-4.0: https://bpsc.bihar.gov.in/wp-json/wp/v2/media?search=TRE-4.0&per_page=100
- BPSC question-booklet archive: https://bpsc.bihar.gov.in/question-booklets/
- Official BPSC exam calendar: https://bpsc.bihar.gov.in/exam-calendar/
- Provisional third-party TRE syllabus transcription (not a BPSC-hosted file): https://www.sarkariresult.com/wp-content/uploads/2026/08/bpsc_Syllabus_TRE_SarkariResult.pdf
- Bihar SCERT eResources catalogue: https://scert.bihar.gov.in/eresources/
- Supplied paper filenames and scope limitations are recorded in `COVERAGE_MATRIX.md`.
