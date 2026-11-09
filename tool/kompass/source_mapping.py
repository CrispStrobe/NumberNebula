"""Read the pinned, deliberately narrow competency export from kompass4.

Interactive tasks and bilingual learning copy remain original NumberNebula
content. This module imports source-owned IDs, classifications and curriculum
metadata without guessing answers or copying the source repository's prose.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAPPING = ROOT / "source_mapping_v1.json"
LOCK = ROOT / "source_mapping.lock.json"
REPOSITORY = "https://github.com/CrispStrobe/kompass4"
EXPORT_PATH = "data/numbernebula_math_mapping_v1.json"
COUNTS = {"Z": ("numbers", 12), "R": ("geometry", 8),
          "G": ("measurement", 7), "D": ("data", 5)}
SKILLS = {f"M-{prefix}{number:02}" for prefix, (_, count) in COUNTS.items()
          for number in range(1, count + 1)}
ROW_FIELDS = {"id", "domain", "evidence", "curriculumUrl", "curriculumCode",
              "curriculumVersion", "estimatedSeconds"}


class SourceMappingError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise SourceMappingError(message)


def validate_mapping(mapping):
    require(isinstance(mapping, dict) and mapping.get("schemaVersion") == 1,
            "unsupported source mapping schema")
    require(set(mapping) == {"schemaVersion", "id", "version", "source", "competencies"},
            "only reviewed source mapping fields may be imported")
    require(mapping.get("id") == "kompass4_numbernebula_math_mapping",
            "wrong source mapping ID")
    require(isinstance(mapping.get("version"), str) and
            re.fullmatch(r"\d+\.\d+\.\d+", mapping["version"]), "source mapping version required")
    source = mapping.get("source", {})
    require(isinstance(source, dict) and source.get("repository") == REPOSITORY,
            "wrong source repository")
    require(set(source) == {"repository", "commit", "path", "sha256", "timeUnit", "timeBasis",
                            "prerequisitesAuthored", "rights", "scope"},
            "only reviewed source provenance fields may be imported")
    require(source.get("path") == "data/kompass_matrix_mathe.json",
            "wrong source matrix path")
    require(isinstance(source.get("commit"), str) and re.fullmatch(r"[0-9a-f]{40}", source["commit"]),
            "immutable source matrix commit required")
    require(isinstance(source.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", source["sha256"]),
            "source matrix SHA-256 required")
    require(source.get("timeUnit") == "seconds" and source.get("timeBasis") == "authorEstimates",
            "matrix time bounds must be explicit author-estimated seconds")
    require(source.get("prerequisitesAuthored") is False,
            "new prerequisites need an explicit reviewed contract")
    rows = mapping.get("competencies")
    require(isinstance(rows, list) and all(isinstance(row, dict) for row in rows),
            "source competencies must be objects")
    ids = [row.get("id") for row in rows]
    require(all(isinstance(key, str) for key in ids) and len(ids) == len(set(ids)) and set(ids) == SKILLS,
            "source mapping must contain exactly the 32 unique mathematics IDs")
    for row in rows:
        key = row["id"]
        require(set(row) == ROW_FIELDS, f"{key}: only reviewed metadata fields may be imported")
        require(row["domain"] == COUNTS[key[2]][0], f"{key}: wrong domain")
        require(row["evidence"] in {"published2025", "curriculum"}, f"{key}: unknown evidence")
        require(isinstance(row["curriculumUrl"], str) and re.fullmatch(
            r"https://www\.bildungsplaene-bw\.de/,Lde/BP2016BW_ALLG_GS_M\.V2_IK_3-4_\d{2}_\d{2}",
            row["curriculumUrl"]), f"{key}: wrong curriculum URL")
        for field in ("curriculumCode", "curriculumVersion"):
            require(isinstance(row[field], str) and row[field].strip(), f"{key}: missing {field}")
        bounds = row["estimatedSeconds"]
        require(isinstance(bounds, dict) and set(bounds) == {"min", "max"}, f"{key}: invalid time bounds")
        require(all(isinstance(value, int) and not isinstance(value, bool) and value > 0
                    for value in bounds.values()) and bounds["min"] <= bounds["max"],
                f"{key}: invalid time bounds")
    return mapping


def make_lock(mapping_bytes, export_commit):
    require(isinstance(export_commit, str) and re.fullmatch(r"[0-9a-f]{40}", export_commit),
            "immutable 40-character export commit required")
    mapping = validate_mapping(json.loads(mapping_bytes))
    return {
        "schemaVersion": 1,
        "repository": REPOSITORY,
        "exportCommit": export_commit,
        "exportPath": EXPORT_PATH,
        "sha256": hashlib.sha256(mapping_bytes).hexdigest(),
        "matrixCommit": mapping["source"]["commit"],
        "matrixSha256": mapping["source"]["sha256"],
    }


def load_source_mapping(mapping_path=MAPPING, lock_path=LOCK):
    raw = Path(mapping_path).read_bytes()
    lock = json.loads(Path(lock_path).read_text(encoding="utf-8"))
    require(isinstance(lock, dict), "source lock must be an object")
    expected = make_lock(raw, lock.get("exportCommit"))
    require(lock == expected,
            "source mapping or provenance changed: review and run sync_mapping.py with an immutable export commit")
    return validate_mapping(json.loads(raw))


def source_metadata():
    """Safe provenance for the bundled course, verified against exact local bytes."""
    load_source_mapping()
    return json.loads(LOCK.read_text(encoding="utf-8"))
