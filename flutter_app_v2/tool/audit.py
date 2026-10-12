#!/usr/bin/env python3
"""Pre-flight audit for flutter_app_v2/lib (run from the repo root).

Checks that the CI cannot catch quickly on its own:

  1. relative imports            — every import must be package:mocktester_v2/…
  2. dangling imports            — imported files must exist
  3. missing imports             — a used app symbol must be imported somewhere
  4. unused app imports          — imported, but no exported symbol is used
  5. delimiter balance           — brackets balanced outside strings/comments

Exit code is non-zero when a hard problem is found (1-3, 5).
"""
import os
import re
import sys
import collections

# Resolve lib/ relative to this script so the audit can be run from anywhere.
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib")
PKG = "package:mocktester_v2/"


# --------------------------------------------------------------- utilities ---
def strip_code(src: str) -> str:
    """Comments blanked, string bodies removed, `${...}` kept (real code)."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        if c in ("'", '"'):
            raw = i > 0 and src[i - 1] == "r"
            q = c
            triple = src[i:i + 3] == c * 3
            i += 3 if triple else 1
            out.append('""')
            while i < n:
                if not raw and src[i] == "\\":
                    i += 2
                    continue
                if triple and src[i:i + 3] == q * 3:
                    i += 3
                    break
                if not triple and src[i] == q:
                    i += 1
                    break
                if src[i] == "\n":
                    out.append("\n")
                    if not triple:
                        break
                if src[i] == "$" and i + 1 < n and src[i + 1] == "{":
                    depth, start, j = 1, i + 2, i + 2
                    while j < n and depth > 0:
                        if src[j] == "{":
                            depth += 1
                        elif src[j] == "}":
                            depth -= 1
                        j += 1
                    out.append(" " + strip_code(src[start:j - 1]) + " ")
                    i = j
                    continue
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def balance_issue(src: str):
    i, n, line = 0, len(src), 1
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                if src[i] == "\n":
                    line += 1
                i += 1
            i += 2
            continue
        if c in ("'", '"'):
            raw = i > 0 and src[i - 1] == "r"
            q = c
            triple = src[i:i + 3] == c * 3
            i += 3 if triple else 1
            while i < n:
                if not raw and src[i] == "\\":
                    i += 2
                    continue
                if triple and src[i:i + 3] == q * 3:
                    i += 3
                    break
                if not triple and src[i] == q:
                    i += 1
                    break
                if src[i] == "\n":
                    line += 1
                    if not triple:
                        break
                if src[i] == "$" and i + 1 < n and src[i + 1] == "{":
                    depth, j = 1, i + 2
                    while j < n and depth > 0:
                        if src[j] == "{":
                            depth += 1
                        elif src[j] == "}":
                            depth -= 1
                        j += 1
                    i = j
                    continue
                i += 1
            continue
        if c in "([{":
            stack.append((c, line))
        elif c in ")]}":
            if not stack or stack[-1][0] != pairs[c]:
                return f"unbalanced '{c}' at line {line}"
            stack.pop()
        i += 1
    if stack:
        return f"unclosed '{stack[-1][0]}' at line {stack[-1][1]}"
    return None


MIRROR_HOSTS = re.compile(
    r"(raw\.githubusercontent\.com|cdn\.jsdelivr\.net|fastly\.jsdelivr\.net"
    r"|cdn\.statically\.io|raw\.githack\.com|api\.github\.com)")


def mirror_hits(rel: str, raw: str):
    """Hardcoded content-delivery hosts outside core/config (see ContentSources)."""
    if "core/config/" in rel.replace("\\", "/"):
        return []
    hits = []
    for i, line in enumerate(raw.split("\n"), 1):
        stripped = line.lstrip()
        if stripped.startswith("//"):  # doc comments may quote example URLs
            continue
        if MIRROR_HOSTS.search(line):
            hits.append(f"{rel}:{i} → {line.strip()[:90]}")
    return hits


def main() -> int:
    files = {}
    for dp, _, fns in os.walk(ROOT):
        for fn in fns:
            if fn.endswith(".dart"):
                p = os.path.join(dp, fn)
                files[os.path.relpath(p, ROOT)] = p

    declared = collections.defaultdict(set)
    for rel, p in files.items():
        code = strip_code(open(p, encoding="utf-8").read())
        for m in re.finditer(
            r"^(?:abstract\s+)?(?:class|enum|mixin|typedef|extension)\s+(\w+)",
            code, re.M,
        ):
            if not m.group(1).startswith("_"):
                declared[m.group(1)].add(rel)

    problems = collections.defaultdict(list)

    for rel, p in files.items():
        raw = open(p, encoding="utf-8").read()
        code = strip_code(raw)
        body = "\n".join(
            l for l in code.split("\n") if not l.strip().startswith("import "))

        imports = re.findall(r"^\s*import\s+'([^']+)'", raw, re.M)
        app_imports = {t[len(PKG):] for t in imports if t.startswith(PKG)}

        for t in imports:
            if not t.startswith("dart:") and not t.startswith("package:"):
                problems["relative"].append(f"{rel}: {t}")
            elif t.startswith(PKG) and not os.path.isfile(
                    os.path.join(ROOT, t[len(PKG):])):
                problems["dangling"].append(f"{rel}: {t}")

        for name, owners in declared.items():
            if rel in owners or not re.search(r"\b" + re.escape(name) + r"\b", body):
                continue
            if not (app_imports & owners):
                problems["missing"].append(
                    f"{rel}: '{name}' used but not imported (in {sorted(owners)})")

        for target in sorted(app_imports):
            exported = declared_symbols_of = None
            tpath = os.path.join(ROOT, target)
            if not os.path.isfile(tpath):
                continue
            exported = set()
            for name, owners in declared.items():
                if target in owners:
                    exported.add(name)
            if exported and not any(
                    re.search(r"\b" + re.escape(s) + r"\b", body) for s in exported):
                problems["unused_app"].append(f"{rel}: {target}")

        for hit in mirror_hits(rel, raw):
            problems["mirrors"].append(hit)

        issue = balance_issue(raw)
        if issue:
            problems["syntax"].append(f"{rel}: {issue}")

    labels = {
        "relative": "relative imports (must be package:)",
        "dangling": "dangling imports",
        "missing": "missing imports",
        "syntax": "unbalanced delimiters",
        "mirrors": "hardcoded CDN/repo hosts outside core/config",
        "unused_app": "unused app imports (warning only)",
    }
    hard = 0
    for key in ("relative", "dangling", "missing", "syntax", "mirrors", "unused_app"):
        items = sorted(problems.get(key, []))
        marker = "OK " if not items else "!! "
        print(f"{marker}{labels[key]}: {len(items)}")
        for it in items[:40]:
            print(f"      {it}")
        if items and key != "unused_app":
            hard += len(items)

    print(f"\n{len(files)} dart files checked")
    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main())
