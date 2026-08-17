#!/usr/bin/env python3
"""Validate SkyScript app manifests.

The manifest is the entire product here, and SkyScript fails soft on a bad one:
an unknown key is ignored and a malformed file drops the app from the Plugins
menu with nothing in Log.txt pointing at why. A typo is therefore silent until
someone launches X-Plane, which is far too late to find it.

No PyYAML dependency on purpose. SkyScript manifests are flat `key: value`
scalars, so parsing them exactly takes less code than pulling in a package that
the person cloning this repo would then have to install.

Usage:
    check-manifests.py                  # validate every apps/*/manifest.yaml
    check-manifests.py PATH [PATH ...]  # validate specific files
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

BOOL_FIELDS = {
    "hide_addressbar",
    "audio_muted",
    "console_logging",
    "window_titleless",
    "notification_sound",
    "default",
}
INT_FIELDS = {"framerate", "minimum_width", "scroll_speed", "width", "height"}
FLOAT_FIELDS = {
    "window_opacity",
    "notification_timeout",
    "notification_timeout_seconds",
    "notification_opacity",
    "notification_slide_seconds",
}
STR_FIELDS = {
    "name",
    "url",
    "homepage",
    "user_agent",
    "forced_language",
    "notification_corner",
    "notification_location",
}
KNOWN_FIELDS = BOOL_FIELDS | INT_FIELDS | FLOAT_FIELDS | STR_FIELDS

NOTIFICATION_CORNERS = {"top-left", "top-right", "bottom-left", "bottom-right"}

TRUE_VALUES = {"true", "yes", "on"}
FALSE_VALUES = {"false", "no", "off"}


def parse_flat_yaml(path: Path) -> tuple[dict[str, tuple[str, int]], list[str]]:
    """Parse a flat key: value document. Returns (fields, errors)."""
    fields: dict[str, tuple[str, int]] = {}
    errors: list[str] = []

    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue

        if line[0] in " \t":
            errors.append(
                f"{path}:{lineno}: indented line -- SkyScript manifests are a flat "
                f"list of key: value pairs, with no nesting"
            )
            continue

        if ":" not in line:
            errors.append(f"{path}:{lineno}: no ':' -- expected `key: value`")
            continue

        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()

        if key in fields:
            errors.append(
                f"{path}:{lineno}: duplicate key '{key}' (first set on line "
                f"{fields[key][1]}) -- the last one silently wins"
            )
        fields[key] = (value, lineno)

    return fields, errors


def check_types(path: Path, fields: dict[str, tuple[str, int]]) -> list[str]:
    errors: list[str] = []

    for key, (value, lineno) in fields.items():
        if key not in KNOWN_FIELDS:
            errors.append(
                f"{path}:{lineno}: unknown field '{key}' -- SkyScript ignores it "
                f"silently, so a typo here does nothing at all"
            )
            continue

        if not value:
            errors.append(f"{path}:{lineno}: '{key}' has no value")
            continue

        unquoted = value.strip("'\"")

        if key in BOOL_FIELDS and unquoted.lower() not in TRUE_VALUES | FALSE_VALUES:
            errors.append(f"{path}:{lineno}: '{key}' must be true or false, got '{value}'")
        elif key in INT_FIELDS and not unquoted.isdigit():
            errors.append(f"{path}:{lineno}: '{key}' must be a whole number, got '{value}'")
        elif key in FLOAT_FIELDS:
            try:
                float(unquoted)
            except ValueError:
                errors.append(f"{path}:{lineno}: '{key}' must be a number, got '{value}'")
        elif key in {"url", "homepage"} and not unquoted.startswith(("http://", "https://")):
            errors.append(
                f"{path}:{lineno}: '{key}' must be an absolute http(s) URL, got '{value}'"
            )
        elif (
            key in {"notification_corner", "notification_location"}
            and unquoted not in NOTIFICATION_CORNERS
        ):
            allowed = ", ".join(sorted(NOTIFICATION_CORNERS))
            errors.append(f"{path}:{lineno}: '{key}' must be one of {allowed}")

    if "window_opacity" in fields:
        value = fields["window_opacity"][0].strip("'\"")
        try:
            # SkyScript clamps to [0.2, 1.0]; a value outside it is not an error
            # but is a number that will not do what it says.
            if not 0.2 <= float(value) <= 1.0:
                errors.append(
                    f"{path}:{fields['window_opacity'][1]}: 'window_opacity' is clamped "
                    f"to 0.2-1.0, so {value} will not take effect as written"
                )
        except ValueError:
            pass

    return errors


def check_app(manifest: Path) -> list[str]:
    fields, errors = parse_flat_yaml(manifest)
    errors += check_types(manifest, fields)

    if "name" not in fields:
        errors.append(
            f"{manifest}: no 'name' -- the app falls back to the folder name in the Plugins menu"
        )

    # A local app with neither a URL nor an index.html opens an empty window.
    if not ({"url", "homepage"} & fields.keys()) and not (manifest.parent / "index.html").is_file():
        errors.append(
            f"{manifest}: no 'url' and no index.html beside it -- "
            f"this app would open a blank window"
        )

    return errors


def main(argv: list[str]) -> int:
    if argv:
        manifests = [Path(arg).resolve() for arg in argv]
    else:
        manifests = sorted((REPO_ROOT / "apps").glob("*/manifest.yaml"))

    manifests = [m for m in manifests if m.is_file()]

    if not manifests:
        print("No manifests to check.", file=sys.stderr)
        return 0

    all_errors: list[str] = []
    for manifest in manifests:
        all_errors += check_app(manifest)

    if all_errors:
        for error in all_errors:
            print(error, file=sys.stderr)
        return 1

    print(f"OK: {len(manifests)} manifest(s) valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
