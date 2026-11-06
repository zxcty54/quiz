#!/usr/bin/env python3
"""Structural release gate for the draft BPSC TRE Revision banks.

This checks JSON shape and mapping integrity only. A passing run is NOT proof of
answer-key correctness, translation quality, syllabus coverage, source validity,
expert review, or compatibility with the live app.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path, PurePosixPath
from typing import Any

REQUIRED_FIELDS = ("qe", "qh", "o", "oe", "oh", "a", "e", "eh")
OPTION_FIELDS = ("o", "oe", "oh")


class DuplicateJSONKey(ValueError):
    pass


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKey(f"duplicate JSON object key: {key!r}")
        result[key] = value
    return result


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)


def normalized_stem(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold()
    return "".join(ch for ch in value if ch.isalnum())


def validate(base: Path, minimum: int) -> tuple[list[str], int, int, int]:
    errors: list[str] = []
    bank_dir = base / "revision"
    banks = sorted(bank_dir.rglob("*.json")) if bank_dir.is_dir() else []
    if not banks:
        return [f"No bank JSON files found under {bank_dir}"], 0, 0, 0

    total_questions = 0
    for path in banks:
        rel = path.relative_to(base).as_posix()
        try:
            data = load_json(path)
        except Exception as exc:  # report each file and keep checking the rest
            errors.append(f"{rel}: invalid JSON ({exc})")
            continue
        if not isinstance(data, list):
            errors.append(f"{rel}: bank root must be a JSON array")
            continue
        if len(data) < minimum:
            errors.append(f"{rel}: {len(data)} questions; minimum is {minimum}")
        total_questions += len(data)
        seen_qe: set[str] = set()
        seen_qh: set[str] = set()

        for index, question in enumerate(data, 1):
            where = f"{rel}[{index}]"
            if not isinstance(question, dict):
                errors.append(f"{where}: question must be an object")
                continue
            missing = [field for field in REQUIRED_FIELDS if field not in question]
            if missing:
                errors.append(f"{where}: missing fields {', '.join(missing)}")
                continue
            forbidden = [key for key in question if str(key).casefold() in {"topic", "subject"}]
            if forbidden:
                errors.append(f"{where}: forbidden question tag(s): {', '.join(forbidden)}")

            for field in ("qe", "qh", "e", "eh"):
                if not isinstance(question[field], str) or not question[field].strip():
                    errors.append(f"{where}: {field} must be a non-empty string")

            for field in OPTION_FIELDS:
                options = question[field]
                if not isinstance(options, list) or len(options) != 5:
                    errors.append(f"{where}: {field} must contain exactly five options")
                    continue
                if any(not isinstance(option, str) or not option.strip() for option in options):
                    errors.append(f"{where}: {field} contains a non-string or blank option")
                normalized_options = [
                    " ".join(unicodedata.normalize("NFKC", option).casefold().split())
                    for option in options
                    if isinstance(option, str)
                ]
                if len(normalized_options) == 5 and len(set(normalized_options)) != 5:
                    errors.append(f"{where}: {field} contains duplicate options")

            if isinstance(question["o"], list) and isinstance(question["oe"], list):
                if question["o"] != question["oe"]:
                    errors.append(f"{where}: legacy `o` options differ from English `oe` options")

            answer = question["a"]
            if type(answer) is not int or not 0 <= answer <= 4:
                errors.append(f"{where}: `a` must be an integer from 0 to 4")

            for field, seen in (("qe", seen_qe), ("qh", seen_qh)):
                stem = question.get(field)
                if isinstance(stem, str) and stem.strip():
                    normalized = normalized_stem(stem)
                    if normalized in seen:
                        errors.append(f"{where}: duplicate normalized {field} stem in this bank")
                    seen.add(normalized)

    mapping_path = base / "subject_mapping_additions.json"
    mapping_refs: list[str] = []
    try:
        overlay = load_json(mapping_path)
        groups = overlay.get("merge_into_subject_mapping") if isinstance(overlay, dict) else None
        if not isinstance(groups, dict) or not groups:
            errors.append("subject_mapping_additions.json: missing non-empty `merge_into_subject_mapping` object")
        else:
            for group, entries in groups.items():
                if not isinstance(entries, dict) or not entries:
                    errors.append(f"subject_mapping_additions.json: {group!r} must contain mapping entries")
                    continue
                for label, rel in entries.items():
                    if not isinstance(label, str) or not label.strip():
                        errors.append(f"subject_mapping_additions.json: blank label in {group!r}")
                    if not isinstance(rel, str):
                        errors.append(f"subject_mapping_additions.json: non-string path for {group!r}/{label!r}")
                        continue
                    posix = PurePosixPath(rel)
                    if posix.is_absolute() or ".." in posix.parts or not rel.startswith("revision/"):
                        errors.append(f"subject_mapping_additions.json: unsafe/non-bank path {rel!r}")
                        continue
                    target = base.joinpath(*posix.parts)
                    if not target.is_file():
                        errors.append(f"subject_mapping_additions.json: missing target {rel!r}")
                    elif target.suffix.lower() != ".json":
                        errors.append(f"subject_mapping_additions.json: target is not JSON: {rel!r}")
                    mapping_refs.append(rel)
    except Exception as exc:
        errors.append(f"subject_mapping_additions.json: invalid JSON or structure ({exc})")

    if len(mapping_refs) != len(set(mapping_refs)):
        errors.append("subject_mapping_additions.json: a bank path is referenced more than once")
    bank_paths = {path.relative_to(base).as_posix() for path in banks}
    if set(mapping_refs) != bank_paths:
        unreferenced = sorted(bank_paths - set(mapping_refs))
        missing_files = sorted(set(mapping_refs) - bank_paths)
        if unreferenced:
            errors.append("Unmapped banks: " + ", ".join(unreferenced))
        if missing_files:
            errors.append("Mapping paths outside the bank inventory: " + ", ".join(missing_files))

    return errors, len(banks), total_questions, len(mapping_refs)


def main() -> int:
    default_base = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=default_base, help="content_base_patch directory")
    parser.add_argument("--min-questions", type=int, default=25, help="minimum questions per bank (default: 25)")
    args = parser.parse_args()
    base = args.base.resolve()
    if args.min_questions < 1:
        parser.error("--min-questions must be at least 1")

    errors, banks, questions, mapped = validate(base, args.min_questions)
    print(f"Banks: {banks} | Questions: {questions} | Mapping entries: {mapped}")
    if errors:
        print(f"STRUCTURAL CHECK: FAIL ({len(errors)} issue(s))")
        for error in errors:
            print(f"- {error}")
        return 1
    print("STRUCTURAL CHECK: PASS")
    print("NOTE: This does not certify answer accuracy, translations, syllabus coverage, expert review, or live-app integration.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
