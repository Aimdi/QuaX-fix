#!/usr/bin/env python3
"""Read-only ARB validation for CI.

Unlike l10n.py this never rewrites a file and needs no Flutter toolchain, so it
can gate every pull request. It fails only on the mistakes that break codegen or
crash at runtime, and warns about the rest.

Errors:
  - a file that is not valid JSON
  - unbalanced braces (intl_utils cannot parse the ICU message)
  - a locale carrying a key the reference does not have (a merge leftover)
  - a translation using a placeholder the reference never declares

Warnings:
  - keys the reference has and a locale does not (normal translation lag)
  - a translation dropping a placeholder the reference interpolates
"""

import json
import re
import sys
from pathlib import Path

L10N_DIR = Path("lib/l10n")
REFERENCE = "intl_en.arb"

# An ARB placeholder is an ASCII identifier right after '{', closed by '}' for a
# plain interpolation or followed by ',' for an ICU plural/select. Anything else
# inside braces is branch text ("two{zwei tweets}") and must not be collected.
PLACEHOLDER = re.compile(r"{([A-Za-z_][A-Za-z0-9_]*)\s*[},]")


def content_keys(data):
    return {k for k in data if not k.startswith("@")}


def placeholders(message):
    return set(PLACEHOLDER.findall(message))


def unbalanced(message):
    depth = 0
    for char in message:
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth < 0:
                return True
    return depth != 0


def load(path, errors):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{path.name}: invalid JSON ({exc})")
        return None


def check_braces(path, data, errors):
    for key in sorted(content_keys(data)):
        if unbalanced(data[key]):
            errors.append(f"{path.name}: '{key}' has unbalanced braces")


def check_locale(path, data, reference, errors, warnings):
    keys = content_keys(data)
    ref_keys = content_keys(reference)

    for key in sorted(keys - ref_keys):
        errors.append(f"{path.name}: '{key}' does not exist in {REFERENCE}")

    dropped = []
    for key in sorted(keys & ref_keys):
        expected = placeholders(reference[key])
        actual = placeholders(data[key])
        unknown = actual - expected
        if unknown:
            errors.append(f"{path.name}: '{key}' uses unknown placeholder(s) {sorted(unknown)}")
        if expected - actual:
            dropped.append(key)

    if dropped:
        warnings.append(f"{path.name}: {len(dropped)} keys drop an interpolated value ({', '.join(dropped[:3])}…)")

    missing = len(ref_keys - keys)
    if missing:
        warnings.append(f"{path.name}: {missing} untranslated keys")


def main():
    errors, warnings = [], []
    reference_path = L10N_DIR / REFERENCE
    reference = load(reference_path, errors)
    if reference is None:
        print(f"error: cannot read {reference_path}", file=sys.stderr)
        return 1

    check_braces(reference_path, reference, errors)

    locales = 0
    for path in sorted(L10N_DIR.glob("intl_*.arb")):
        if path.name == REFERENCE:
            continue
        data = load(path, errors)
        if data is None:
            continue
        locales += 1
        check_braces(path, data, errors)
        check_locale(path, data, reference, errors, warnings)

    for warning in warnings:
        print(f"warning: {warning}")

    for error in errors:
        print(f"error: {error}", file=sys.stderr)

    if errors:
        print(f"\n{len(errors)} ARB error(s).", file=sys.stderr)
        return 1

    print(f"\n{len(content_keys(reference))} keys across {locales} locales, no errors.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
