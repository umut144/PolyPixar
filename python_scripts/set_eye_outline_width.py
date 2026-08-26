#!/usr/bin/env python3
"""Retired offline helper for eye contour widths.

Use PolyTools instead: World -> Set Eye Contour Width… .  That command changes
the live World document, supports Undo, refreshes the canvas/export preflight,
and saves through PolyTools.  This script deliberately no longer writes Asset
JSON files behind a running editor's back.
"""

from __future__ import annotations

import argparse
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="retained for compatibility; no files are written")
    parser.parse_args()
    print("No files were changed.")
    print("Open PolyTools and use World -> Set Eye Contour Width… instead.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
