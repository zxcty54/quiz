# BPSC TRE Revision Banks — copy-ready Content Base overlay

This directory contains **25 original Revision practice banks (252 MCQs)** for BPSC TRE Primary (Classes 1–5), Middle (6–8), and Secondary (9–10). It does not add sectional mocks, Learning lessons, or Classes 11–12 content. The questions are newly written practice items; none are labelled or represented as official previous-year questions. See `COVERAGE_MATRIX.md` for source confidence, bank-by-bank inventory, and unresolved gaps.

## Copying into `content_base`

1. Copy `content_base_patch/revision/` into the root of the Content Base repository, preserving the relative paths.
2. Merge the entries in `subject_mapping_additions.json` into the matching objects in Content Base's existing `subject_mapping.json`. **Do not replace the entire mapping** with the additions file.
3. The current Revision screen has no Language hub. Language files and their proposed `language_mapping` entries are included as copy-ready data but will not be reachable in that UI until a Language hub is added. No Flutter/app code was changed in this work.
4. `COVERAGE_MATRIX.md` records the evidence and the remaining verification gaps.

## JSON format

Each bank is an array of records using the Revision model's supported keys: `qe`, `qh`, `o`, `oe`, `oh`, `a`, `e`, and `eh`. `o`/`oe` contain the English choices and `oh` contains the Hindi choices; `a` is a zero-based integer from 0 to 4. Each question has five choices. `o` is retained for compatibility with older Content Base readers. The bank records contain no `topic`/`subject` tags. Hindi question text and explanations are supplied; English is the fallback. Files are original practice, not copied PYQ text.

## Provisional-source warning

The official BPSC Advertisement 15/2026 PDF is listed in BPSC's media index, but its full contents could not be retrieved/parsed during this audit. The readable TRE-4 syllabus transcription is hosted by a third party and contains an internal Main-duration inconsistency. Therefore the high-level stage/section mapping is **provisional**; this package does not claim exhaustive or officially verified chapter-level TRE-4 coverage. Please re-check the official advertisement/admit-card instructions before using any timing or marking assumptions.

## Source links

- BPSC Advertisement 15/2026 (official PDF URL listed in BPSC media index): https://bpsc.bihar.gov.in/wp-content/uploads/BPSC_content/Notices/Advertisement-152026-TRE-4.0_BPSC-20260922-dbsf04.pdf
- BPSC media index search for TRE-4.0: https://bpsc.bihar.gov.in/wp-json/wp/v2/media?search=TRE-4.0&per_page=100
- BPSC question-booklet archive: https://bpsc.bihar.gov.in/question-booklets/
- Official BPSC exam calendar: https://bpsc.bihar.gov.in/exam-calendar/
- Provisional third-party TRE syllabus transcription (not a BPSC-hosted file): https://www.sarkariresult.com/wp-content/uploads/2026/08/bpsc_Syllabus_TRE_SarkariResult.pdf
- Bihar SCERT eResources catalogue: https://scert.bihar.gov.in/eresources/
- Supplied booklets used for structure/pattern review are listed by filename in `COVERAGE_MATRIX.md`; they remain in the supplied upload area and are not copied into this patch.
