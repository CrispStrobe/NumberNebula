"""Prove that historical task wording, scoring and figures remain identical."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

BASELINE = Path(__file__).with_name("baselines") / "math_v2_0_1.json"
BASELINE_SHA256 = "5c71c27ee35a2853407f968348b7e2b57877cbbaa292ad4f90fcb9a0a4fee54a"


def compatibility_for(tasks):
    raw = BASELINE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASELINE_SHA256:
        raise ValueError("Historical content baseline changed; review a migration explicitly.")
    baseline = json.loads(raw)
    current = {task["id"]: task for task in tasks}
    if len(current) != len(tasks):
        raise ValueError("Duplicate task IDs cannot establish compatibility.")
    identical = []
    for previous in baseline["tasks"]:
        if current.get(previous["id"]) != previous:
            raise ValueError(f"Historical task {previous['id']} changed; do not reuse its rubric or saved session.")
        identical.append(previous["id"])
    return {baseline["version"]: sorted(identical)}


def verify_compatibility(package):
    expected = compatibility_for(package["tasks"])
    if package.get("compatibleTaskIds") != expected:
        raise ValueError("Compatible task IDs must match the immutable historical content exactly.")
