#!/usr/bin/env python3
"""Lint App Store metadata before pushing.

Checks the things `asc metadata validate` does not: UTF-16 length (App Store Connect counts
UTF-16 code units, not characters), keyword byte budget, words duplicated between name /
subtitle / keywords, third-party trademarks in the keyword field (Guideline 2.3.7), and
leftover placeholders. Exit code 1 on any error.

    python3 scripts/lint-metadata.py [metadata-dir]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "metadata")

LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotionalText": 170,
    "description": 4000,
    "whatsNew": 4000,
}
KEYWORD_BYTE_LIMIT = 100
# Terms Apple has rejected in the keyword field as unauthorized trademarks. Fine in the description
# as compatibility statements ("works with Claude Code"), not fine as indexed keywords.
TRADEMARKS = {
    "claude", "anthropic", "codex", "openai", "chatgpt", "gpt", "copilot", "gemini",
    "apple", "mac", "macos", "iphone", "ipad", "xcode", "siri",
}
PLACEHOLDERS = re.compile(r"\b(TODO|TBD|FIXME|lorem|example\.com|待确认|待定)\b", re.I)

errors: list[str] = []
warnings: list[str] = []


def utf16_len(text: str) -> int:
    return len(text.encode("utf-16-le")) // 2


def words(text: str) -> set[str]:
    return {w for w in re.split(r"[\s,，、·:：/\-]+", text.lower()) if len(w) > 1}


def check_limits(file: Path, data: dict) -> None:
    for field, limit in LIMITS.items():
        value = data.get(field)
        if not value:
            continue
        cp, u16 = len(value), utf16_len(value)
        if max(cp, u16) > limit:
            errors.append(f"{file}: {field} is {cp} chars / {u16} UTF-16 units, limit {limit}")
        if PLACEHOLDERS.search(value):
            errors.append(f"{file}: {field} contains a placeholder")
    for field in ("privacyPolicyUrl", "supportUrl", "marketingUrl"):
        url = data.get(field)
        if url and not re.match(r"^https://[^\s]+$", url):
            errors.append(f"{file}: {field} must be an https URL, got {url!r}")


def check_keywords(file: Path, keywords: str, name: str, subtitle: str) -> None:
    nbytes = len(keywords.encode("utf-8"))
    if nbytes > KEYWORD_BYTE_LIMIT:
        errors.append(f"{file}: keywords are {nbytes} bytes, limit {KEYWORD_BYTE_LIMIT}")
    if ", " in keywords:
        warnings.append(f"{file}: keywords contain ', ' — drop the spaces to save bytes")
    terms = [k.strip().lower() for k in keywords.split(",") if k.strip()]
    for term in terms:
        for tm in TRADEMARKS:
            if re.fullmatch(rf"{tm}( \w+)?", term):
                errors.append(f"{file}: keyword {term!r} is a third-party trademark (Guideline 2.3.7)")
    dupes = set(terms) & (words(name) | words(subtitle))
    if dupes:
        warnings.append(f"{file}: keywords repeat name/subtitle words {sorted(dupes)} — already indexed, wasted bytes")
    if len(terms) != len(set(terms)):
        warnings.append(f"{file}: duplicate keywords")


app_info = {p.stem: json.loads(p.read_text()) for p in (ROOT / "app-info").glob("*.json")}
if not app_info:
    errors.append(f"{ROOT}/app-info has no locale files")

for locale, data in app_info.items():
    check_limits(ROOT / "app-info" / f"{locale}.json", data)
    if words(data.get("name", "")) & words(data.get("subtitle", "")):
        warnings.append(f"app-info/{locale}.json: name and subtitle share words — both are indexed, avoid repeats")

for version_dir in sorted((ROOT / "version").glob("*")):
    version_locales = {p.stem for p in version_dir.glob("*.json")}
    missing = set(app_info) - version_locales
    if missing:
        errors.append(f"{version_dir}: missing version metadata for locales {sorted(missing)}")
    for p in sorted(version_dir.glob("*.json")):
        data = json.loads(p.read_text())
        check_limits(p, data)
        info = app_info.get(p.stem, {})
        if "keywords" in data:
            check_keywords(p, data["keywords"], info.get("name", ""), info.get("subtitle", ""))
        for required in ("description", "keywords", "supportUrl"):
            if not data.get(required):
                errors.append(f"{p}: {required} is required for submission")

for w in warnings:
    print(f"warning: {w}")
for e in errors:
    print(f"error: {e}")
print(f"{len(errors)} errors, {len(warnings)} warnings across {len(app_info)} locale(s)")
sys.exit(1 if errors else 0)
