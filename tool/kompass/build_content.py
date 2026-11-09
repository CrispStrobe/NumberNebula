#!/usr/bin/env python3
"""Rebuild the reviewable course asset from its original authoring sources."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from competencies import competencies
from content_numbers import tasks as number_tasks
from content_geometry import tasks as geometry_tasks
from content_measurement import tasks as measurement_tasks
from content_data import tasks as data_tasks
from content_extension import tasks as extension_tasks
from content_compatibility import compatibility_for
from source_mapping import source_metadata

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "assets/kompass/math_v2.json"


def build_package():
    tasks = number_tasks() + geometry_tasks() + measurement_tasks() + data_tasks() + extension_tasks()
    return {
        "schemaVersion": 2,
        "id": "numbernebula_kompass_math",
        "version": "2.1.0",
        "compatibleTaskIds": compatibility_for(tasks),
        "source": {
            "kind": "original",
            "license": "AGPL-3.0-only",
            "authoringReference": "https://github.com/CrispStrobe/kompass4",
            "referenceCommit": "9a0b25a6b0706b7c7944836e00f163bcbfd46676",
            "competencyMapping": source_metadata(),
            "scope": "Original bilingual mathematics exercises authored for NumberNebula; project-owned competency identifiers are retained. No official test item or official answer booklet is embedded or adapted.",
            "officialInformation": "https://ibbw-bw.de/,Lde/Startseite/Pruefungen%2B_%2BLernstandserhebungen/Kompass%2B4-%2BKonzeption",
            "assessmentLimits": "Practice evidence is not an official KOMPASS score, school recommendation, calibrated difficulty, or predicted result. Times are author estimates, not learner norms.",
        },
        "competencies": competencies(),
        "tasks": tasks,
    }


def serialized(package):
    return json.dumps(package, ensure_ascii=False, indent=2) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the committed asset differs from its sources.")
    args = parser.parse_args()
    package = build_package()
    expected = serialized(package)
    if args.check:
        if not ASSET.is_file() or ASSET.read_text(encoding="utf-8") != expected:
            raise SystemExit("Content asset is stale. Run python3 -B tool/kompass/build_content.py")
    else:
        ASSET.parent.mkdir(parents=True, exist_ok=True)
        ASSET.write_text(expected, encoding="utf-8")
    print(f"{len(package['competencies'])} competencies; {len(package['tasks'])} original tasks; reproducible asset {'checked' if args.check else 'written'}.")


if __name__ == "__main__":
    main()
