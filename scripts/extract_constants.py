#!/usr/bin/env python3
"""Extract classifier data from a go-enry checkout into Hansa's sources.

Usage, from the hansa repo root with go-enry checked out next to it:

    python scripts/extract_constants.py [path-to-go-enry]

Outputs:
  go-enry/data/frequencies.go  -> src/data/frequencies.json
  go-enry/data/interpreter.go  -> src/interpreter_table.cr
  go-enry/data/alias.go        -> src/alias_table.cr

Run `ameba --fix` afterwards to normalize the formatting of the
generated Crystal tables.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENRY = Path(sys.argv[1] if len(sys.argv) > 1 else "go-enry")

GENERATED_HEADER = (
    "# Generated from go-enry {tag} (linguist commit {linguist}) by"
    " scripts/extract_constants.py - do not edit."
)


def enry_version():
    try:
        tag = subprocess.run(
            ["git", "-C", str(ENRY), "describe", "--tags"],
            capture_output=True, text=True, check=True,
        )
        return tag.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        version = (ENRY / "go.mod").read_text()
        return re.search(r"go-enry/v\d+", version).group(0)


def linguist_commit():
    for path in (ENRY / "data").glob("*.go"):
        match = re.search(r"linguist commit: (\w+)", path.read_text())
        if match:
            return match.group(1)
    return "unknown"


def extract_frequencies():
    dict_begin = re.compile(r"var (\w*) = .*{")
    nested_dict_begin = re.compile(r'.*"(.*)": .*{')
    dict_item = re.compile(r'.*"(.*)":\s+([+-]?([0-9]*[.])?[0-9]+),')

    data = {}
    stack = [data]
    current = data
    for line in open(ENRY / "data" / "frequencies.go"):
        if "map[string]float64{}," in line:
            # special case, only empty map
            continue
        if dict_begin.match(line):
            dict_name = dict_begin.match(line).groups()[0]
            current[dict_name] = {}
            current = current[dict_name]
            stack.append(current)
        if nested_dict_begin.match(line):
            dict_name = nested_dict_begin.match(line).groups()[0]
            current[dict_name] = {}
            current = current[dict_name]
            stack.append(current)
        else:
            if "}\n" in line or "},\n" in line:
                stack.pop()
                if len(stack) == 0:
                    break
                current = stack[-1]
                continue
            if dict_item.match(line):
                key, value = dict_item.match(line).groups()[0:2]
                current[key] = float(value)

    tokens_total = re.search(
        r"var TokensTotal = ([0-9.]+)",
        (ENRY / "data" / "frequencies.go").read_text(),
    )
    data["TokensTotal"] = float(tokens_total.group(1))

    output = ROOT / "src" / "data" / "frequencies.json"
    output.write_text(json.dumps(data, indent=4))
    print(f"wrote {output}")


def crystal_string(value):
    return json.dumps(value)


def extract_interpreters(header):
    entry = re.compile(r'^\t"(.*)":\s+\{(.*)\},$')
    lines = [header]
    lines.append("module Hansa")
    lines.append("  LANGUAGES_BY_INTERPRETER = {")
    count = 0
    for line in open(ENRY / "data" / "interpreter.go"):
        match = entry.match(line.rstrip("\n"))
        if not match:
            continue
        languages = [language.strip() for language in match.group(2).split(",")]
        languages = [language.strip('"') for language in languages if language.strip()]
        rendered = ", ".join(crystal_string(language) for language in languages)
        lines.append(f"    {crystal_string(match.group(1))} => [{rendered}],")
        count += 1
    lines.append("  } of String => Array(String)")
    lines.append("end")
    output = ROOT / "src" / "interpreter_table.cr"
    output.write_text("\n".join(lines) + "\n")
    print(f"wrote {output} ({count} interpreters)")


def extract_aliases(header):
    entry = re.compile(r'^\t"(.*)":\s+"(.*)",$')
    lines = [header]
    lines.append("module Hansa")
    lines.append("  # Keys are lower case with whitespace replaced by")
    lines.append("  # underscores, so lookups must convert first (see")
    lines.append("  # .language_by_alias).")
    lines.append("  LANGUAGE_BY_ALIAS = {")
    count = 0
    for line in open(ENRY / "data" / "alias.go"):
        match = entry.match(line.rstrip("\n"))
        if not match:
            continue
        lines.append(f"    {crystal_string(match.group(1))} => {crystal_string(match.group(2))},")
        count += 1
    lines.append("  } of String => String")
    lines.append("end")
    output = ROOT / "src" / "alias_table.cr"
    output.write_text("\n".join(lines) + "\n")
    print(f"wrote {output} ({count} aliases)")


def main():
    header = GENERATED_HEADER.format(tag=enry_version(), linguist=linguist_commit())
    extract_frequencies()
    extract_interpreters(header)
    extract_aliases(header)


if __name__ == "__main__":
    main()
