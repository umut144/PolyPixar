#!/usr/bin/env python3
"""Set the contour outline-width override for Components whose name contains "eye".

Run without arguments to preview the affected Components.  Pass --apply only
after checking that list; existing Contour Mesh bakes will then be stale and
should be rebuilt in PolyTools.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


# Change this value to the desired outline width in authored pixels.
OUTLINE_WIDTH_PX = 1.0

# A Component is selected when its name contains this text, case-insensitively.
# With the default, names such as eye_left, eye_right, and eyebrow_left match.
NAME_CONTAINS = "eye"


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ASSETS_ROOT = REPOSITORY_ROOT / "worlds"


def is_valid_width(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        and float(value) > 0.0
    )


def asset_files() -> list[Path]:
    """Return only persisted Asset documents, never derived geometry files."""
    return sorted(ASSETS_ROOT.glob("*/assets/**/*.json"))


def load_document(path: Path) -> dict[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"{path}: cannot read valid JSON ({error})") from error
    if not isinstance(document, dict):
        raise RuntimeError(f"{path}: Asset document must be a JSON object")
    return document


def matching_components(document: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
    matches: list[dict[str, Any]] = []
    skipped_references: list[str] = []
    needle = NAME_CONTAINS.casefold()
    for component in document.get("components", []):
        if not isinstance(component, dict):
            continue
        name = str(component.get("name", ""))
        if needle not in name.casefold():
            continue
        if str(component.get("type", "component")) == "reference":
            skipped_references.append(name)
            continue
        matches.append(component)
    return matches, skipped_references


def write_document(path: Path, document: dict[str, Any]) -> None:
    # Godot's persisted JSON uses tabs and a trailing newline.
    path.write_text(json.dumps(document, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write the changes (default: preview only)")
    arguments = parser.parse_args()

    if not is_valid_width(OUTLINE_WIDTH_PX):
        print("OUTLINE_WIDTH_PX must be a finite number greater than zero.", file=sys.stderr)
        return 2
    if not NAME_CONTAINS.strip():
        print("NAME_CONTAINS must not be empty.", file=sys.stderr)
        return 2

    files = asset_files()
    if not files:
        print(f"No Asset JSON files found below {ASSETS_ROOT}.", file=sys.stderr)
        return 1

    matching_count = 0
    changed_count = 0
    skipped_references: list[str] = []
    for path in files:
        document = load_document(path)
        components, references = matching_components(document)
        relative_path = path.relative_to(REPOSITORY_ROOT)
        skipped_references.extend(f"{relative_path}: {name}" for name in references)
        if not components:
            continue

        dirty = False
        for component in components:
            matching_count += 1
            previous = component.get("contour_stroke_width_px")
            component_id = str(component.get("id", "<without id>"))
            state = "unchanged" if previous == OUTLINE_WIDTH_PX else f"{previous!r} -> {OUTLINE_WIDTH_PX}"
            print(f"{relative_path}: {component_id} ({component.get('name', '')})  {state}")
            if previous != OUTLINE_WIDTH_PX:
                component["contour_stroke_width_px"] = OUTLINE_WIDTH_PX
                dirty = True
                changed_count += 1

        if arguments.apply and dirty:
            write_document(path, document)

    mode = "Applied" if arguments.apply else "Preview"
    print(f"\n{mode}: {matching_count} matching non-reference Component(s); {changed_count} change(s).")
    if not arguments.apply and changed_count:
        print("Run again with --apply to write the changes.")
    if skipped_references:
        print("\nSkipped Reference Component(s); their source Asset owns the geometry/style:")
        print("\n".join(f"  {item}" for item in skipped_references))
    if arguments.apply and changed_count:
        print("Rebuild the affected Contour Meshes in PolyTools before exporting.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
