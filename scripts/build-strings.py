#!/usr/bin/env python3
"""Merge localization/<lang>.json into SkillHub/Resources/Localizable.xcstrings.

Keys are the zh-Hans source strings extracted by `xcodebuild -exportLocalizations`
(pass the .xliff path to refresh the key list). Fails if a translation is missing or
its format specifiers (%@ / %lld, with or without positions) do not match the key.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "SkillHub/Resources/Localizable.xcstrings"
LOC = ROOT / "localization"
LANGS = ["en", "zh-Hant", "ja", "ko", "es", "fr", "de"]
# Strings that read the same in every language; kept out of the translation tables.
UNTRANSLATED = {"%lld", "%lld.", "•", "SKILL.md", "Skill", "Skill Hub", "description", "Prompts", "Skills"}

SPEC = re.compile(r"%(\d+\$)?(@|lld|d|ld|f|s)")


def specs(text: str) -> list[str]:
    return sorted(m.group(2) for m in SPEC.finditer(text))


def keys_from_xliff(path: Path) -> list[str]:
    ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
    root = ET.parse(path).getroot()
    for f in root.findall("x:file", ns):
        if "Localizable" in (f.get("original") or ""):
            return sorted({u.get("id") for u in f.findall(".//x:trans-unit", ns)})
    return []


def main() -> int:
    if len(sys.argv) > 1:
        keys = keys_from_xliff(Path(sys.argv[1]))
        (LOC / "keys.json").write_text(json.dumps(keys, ensure_ascii=False, indent=0) + "\n")
    else:
        keys = json.loads((LOC / "keys.json").read_text())

    tables = {lang: json.loads((LOC / f"{lang}.json").read_text()) for lang in LANGS}
    problems = []
    strings = {}
    for key in keys:
        entry = {"localizations": {}}
        if key in UNTRANSLATED:
            entry["shouldTranslate"] = False
            strings[key] = entry
            continue
        for lang in LANGS:
            value = tables[lang].get(key)
            if value is None:
                problems.append(f"[{lang}] missing: {key!r}")
                continue
            if specs(value) != specs(key):
                problems.append(f"[{lang}] format mismatch: {key!r} -> {value!r}")
            entry["localizations"][lang] = {"stringUnit": {"state": "translated", "value": value}}
        strings[key] = entry

    for lang, table in tables.items():
        for extra in set(table) - set(keys):
            problems.append(f"[{lang}] unused key: {extra!r}")

    if problems:
        print("\n".join(problems))
        return 1

    catalog = {"sourceLanguage": "zh-Hans", "strings": strings, "version": "1.0"}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"wrote {len(strings)} keys × {len(LANGS)} languages -> {CATALOG.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
