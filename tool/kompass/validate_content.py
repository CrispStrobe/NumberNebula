#!/usr/bin/env python3
"""Validate the course contract, holdout partitions and graphical givens.

Structural validation is not empirical calibration or a proof of every prose
answer. Independent mathematical regressions live in test_content.py.
"""
from __future__ import annotations

import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

from content_compatibility import verify_compatibility

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "assets/kompass/math_v2.json"
DOMAINS = {"numbers", "geometry", "measurement", "data"}
USES = {"practice", "check", "rehearsal"}
FIGURES = {"wall", "numberLine", "placeValue", "grid", "table", "barChart",
           "cubePlan", "cubeNet", "clock", "tokenBag", "spinner",
           "shapeComparison", "measureLine", "polygon", "mirror"}
SKILLS = {f"M-{prefix}{number:02}" for prefix, limit in [("Z", 12), ("R", 8), ("G", 7), ("D", 5)]
          for number in range(1, limit + 1)}


class ContentError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ContentError(message)


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def localized(value, where):
    require(isinstance(value, dict) and set(value) == {"de", "en"}, f"{where}: de/en text required")
    for language, text in value.items():
        require(isinstance(text, str) and text.strip(), f"{where}.{language}: empty text")
        require(not any(ord(char) < 32 and char not in "\n\t" for char in text), f"{where}.{language}: control character")
        require(not re.search(r"<\s*(?:script|iframe|img)\b", text, re.I), f"{where}: unsupported HTML")


def label(value, where):
    if isinstance(value, dict):
        localized(value, where)
    else:
        require(isinstance(value, str) and bool(value), f"{where}: label must be string or localized text")


def coordinate(value, where):
    require(isinstance(value, str) and re.fullmatch(r"\d+,\d+", value), f"{where}: cell must be zero-based 'row,col'")
    return tuple(map(int, value.split(",")))


def coordinates(values, where, rows=None, cols=None):
    require(isinstance(values, list), f"{where}: cell list required")
    require(len(values) == len(set(values)), f"{where}: duplicate cell")
    result = [coordinate(value, where) for value in values]
    for row, col in result:
        require(rows is None or row < rows, f"{where}: row outside bounds")
        require(cols is None or col < cols, f"{where}: column outside bounds")
    return result


def positive_int(value):
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def canonical_shape(cells):
    """Translation/rotation/reflection invariant shape fingerprint."""
    points = [coordinate(cell, "shape") for cell in cells]
    variants = []
    for swap in (False, True):
        for row_sign in (-1, 1):
            for col_sign in (-1, 1):
                transformed = [(row_sign * (c if swap else r), col_sign * (r if swap else c)) for r, c in points]
                r0, c0 = min(r for r, _ in transformed), min(c for _, c in transformed)
                variants.append(tuple(sorted((r - r0, c - c0) for r, c in transformed)))
    return min(variants)


def validate_figure(fig, where):
    require(isinstance(fig, dict) and set(fig) == {"kind", "data", "alt"}, f"{where}: figure contract")
    kind, data = fig["kind"], fig["data"]
    require(kind in FIGURES and isinstance(data, dict), f"{where}: unsupported figure")
    localized(fig["alt"], where + ".alt")
    require(not set(data).intersection({"answer", "answers", "solution", "solutions", "correct", "complete_bottom_up"}), f"{where}: answer data in student figure")
    if kind in {"grid", "mirror", "cubeNet"}:
        rows, cols = data.get("rows"), data.get("cols")
        require(positive_int(rows) and positive_int(cols) and rows <= 12 and cols <= 12, f"{where}: invalid grid bounds")
        field = "filled" if kind == "grid" else "cells"
        coordinates(data.get(field, []), where, rows, cols)
        if kind == "mirror":
            axis = data.get("axis", {})
            require(axis.get("direction") in {"vertical", "horizontal"}, f"{where}: invalid mirror direction")
            at = axis.get("at")
            bound = cols if axis["direction"] == "vertical" else rows
            require(isinstance(at, int) and 0 < at < bound, f"{where}: mirror must be an internal grid line")
        if kind == "cubeNet":
            labels = data.get("labels", {})
            require(isinstance(labels, dict) and set(labels).issubset(data["cells"]), f"{where}: label outside net")
            for text in labels.values():
                label(text, where + ".labels")
    elif kind == "wall":
        rows = data.get("rows", [])
        require(isinstance(rows, list) and 2 <= len(rows) <= 5, f"{where}: invalid wall")
        for index, row in enumerate(rows):
            require(isinstance(row, list) and len(row) == len(rows) - index, f"{where}: wall row length")
            require(all(value is None or finite(value) for value in row), f"{where}: invalid wall value")
    elif kind == "numberLine":
        low, high, step = data.get("min"), data.get("max"), data.get("step")
        require(all(finite(value) for value in [low, high, step]) and high > low and step > 0, f"{where}: invalid number line")
        require(math.isclose((high - low) / step, round((high - low) / step)), f"{where}: step does not divide range")
        for mark in data.get("marks", []):
            require(finite(mark.get("value")) and low <= mark["value"] <= high, f"{where}: mark outside range")
            label(mark.get("label"), where + ".mark")
    elif kind == "placeValue":
        columns = data.get("columns", [])
        require(isinstance(columns, list) and columns, f"{where}: missing columns")
        for column in columns:
            label(column.get("label"), where + ".column")
            require(isinstance(column.get("value"), int) and column["value"] >= 0, f"{where}: invalid bundle count")
    elif kind == "table":
        headers, rows = data.get("headers"), data.get("rows")
        require(isinstance(headers, list) and headers and isinstance(rows, list) and rows, f"{where}: empty table")
        for cell in headers:
            label(cell, where + ".header")
        for row in rows:
            require(isinstance(row, list) and len(row) == len(headers), f"{where}: inconsistent table widths")
            for cell in row:
                label(cell, where + ".cell")
    elif kind == "barChart":
        labels, values = data.get("labels"), data.get("values")
        maximum, step = data.get("max"), data.get("step")
        require(isinstance(labels, list) and labels and isinstance(values, list) and len(labels) == len(values), f"{where}: chart data mismatch")
        require(all(finite(value) and value >= 0 for value in values), f"{where}: invalid chart count")
        require(finite(maximum) and maximum >= max(values) and finite(step) and step > 0, f"{where}: invalid chart scale")
        require(math.isclose(maximum / step, round(maximum / step)), f"{where}: axis top must be a labelled tick")
        for text in labels:
            label(text, where + ".category")
        if "yLabel" in data:
            label(data["yLabel"], where + ".yLabel")
    elif kind == "cubePlan":
        heights = data.get("heights", [])
        require(isinstance(heights, list) and heights and heights[0], f"{where}: empty cube plan")
        width = len(heights[0])
        require(all(isinstance(row, list) and len(row) == width for row in heights), f"{where}: ragged cube plan")
        require(all(isinstance(h, int) and 0 <= h <= 8 for row in heights for h in row), f"{where}: invalid tower")
        require(data.get("view") in {"front", "right"}, f"{where}: unsupported view")
    elif kind == "clock":
        require(isinstance(data.get("hour"), int) and 0 <= data["hour"] < 24, f"{where}: invalid hour")
        require(isinstance(data.get("minute"), int) and 0 <= data["minute"] < 60, f"{where}: invalid minute")
    elif kind == "tokenBag":
        require(isinstance(data.get("tokens"), list) and data["tokens"], f"{where}: empty bag")
        for item in data["tokens"]:
            label(item.get("label"), where + ".token")
            require(positive_int(item.get("count")), f"{where}: invalid token count")
    elif kind == "spinner":
        require(isinstance(data.get("sectors"), list) and len(data["sectors"]) >= 2, f"{where}: spinner needs sectors")
        for item in data["sectors"]:
            label(item.get("label"), where + ".sector")
            require(finite(item.get("weight")) and item["weight"] > 0, f"{where}: invalid sector weight")
    elif kind == "shapeComparison":
        shapes = data.get("shapes", [])
        require(isinstance(shapes, list) and 2 <= len(shapes) <= 5, f"{where}: invalid shape comparison")
        require(len({shape.get("id") for shape in shapes}) == len(shapes), f"{where}: duplicate shape ID")
        for shape in shapes:
            label(shape.get("id"), where + ".shape.id")
            require(bool(shape.get("cells")), f"{where}: empty shape")
            coordinates(shape["cells"], where)
    elif kind == "measureLine":
        start, end, step = data.get("start"), data.get("end"), data.get("step")
        require(all(finite(value) for value in [start, end, step]) and end > start and step > 0, f"{where}: invalid measurement scale")
        label(data.get("unit"), where + ".unit")
    elif kind == "polygon":
        points = data.get("points", [])
        require(isinstance(points, list) and len(points) >= 3, f"{where}: polygon needs vertices")
        require(all(isinstance(point, list) and len(point) == 2 and all(finite(value) for value in point) for point in points), f"{where}: invalid polygon point")
        area2 = sum(points[i][0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * points[i][1] for i in range(len(points)))
        require(abs(area2) > 0, f"{where}: zero-area polygon")


def validate_package(package, *, complete=True):
    require(package.get("schemaVersion") == 2, "schemaVersion must be 2")
    require(package.get("id") == "numbernebula_kompass_math", "unexpected package ID")
    require(re.fullmatch(r"\d+\.\d+\.\d+", package.get("version", "")), "semantic package version required")
    require(package.get("source", {}).get("kind") == "original", "original provenance required")
    require(package["source"].get("license") == "AGPL-3.0-only", "package license must match repository")
    competencies = package.get("competencies", [])
    ids = [item.get("id") for item in competencies]
    require(len(ids) == len(set(ids)) and set(ids) == SKILLS, "all 32 unique project-owned competencies required")
    catalog = {item["id"]: item for item in competencies}
    registry = (ROOT / "lib/features/games/game_registry.dart").read_text(encoding="utf-8")
    game_keys = set(re.findall(r"'([^']+)': _DeferredGame", registry))
    for competency in competencies:
        where = competency["id"]
        require(competency.get("domain") in DOMAINS, f"{where}: invalid domain")
        localized(competency.get("title"), where + ".title")
        localized(competency.get("goal"), where + ".goal")
        require(competency.get("evidence") in {"published2025", "curriculum"}, f"{where}: invalid evidence classification")
        require(competency.get("curriculumUrl", "").startswith("https://www.bildungsplaene-bw.de/"), f"{where}: curriculum reference missing")
        require(set(competency.get("gameKeys", [])).issubset(game_keys), f"{where}: unknown registered game key")
    tasks = package.get("tasks", [])
    require(bool(tasks), "empty task bank")
    require(len({item.get("id") for item in tasks}) == len(tasks), "duplicate task ID")
    families = defaultdict(set)
    coverage = defaultdict(Counter)
    prompts = set()
    for item in tasks:
        where = item.get("id", "missing-id")
        require(re.fullmatch(r"m[zrgd]\d{2}_[a-z0-9_]+", where), f"{where}: invalid item ID")
        require(item.get("use") in USES and item.get("domain") in DOMAINS, f"{where}: invalid mode/domain")
        require(item.get("level") in {1, 2, 3}, f"{where}: invalid local difficulty")
        require(isinstance(item.get("familyId"), str) and item["familyId"], f"{where}: family ID required")
        families[item["familyId"]].add(item["use"])
        for field in ["title", "prompt", "solution"]:
            localized(item.get(field), where + "." + field)
        normalized_prompt = re.sub(r"\s+", " ", item["prompt"]["de"]).strip()
        require(normalized_prompt not in prompts, f"{where}: duplicate prompt")
        prompts.add(normalized_prompt)
        require(isinstance(item.get("hints"), list) and item["hints"], f"{where}: missing learning hints")
        for hint in item["hints"]:
            localized(hint, where + ".hint")
        require(positive_int(item.get("estimatedSeconds")), f"{where}: positive time estimate required")
        require(item.get("source", {}).get("kind") == "original" and item["source"].get("license") == "AGPL-3.0-only", f"{where}: original item provenance required")
        if "figure" in item:
            validate_figure(item["figure"], where + ".figure")
        parts = item.get("parts", [])
        require(isinstance(parts, list) and parts and len({part.get("id") for part in parts}) == len(parts), f"{where}: missing/duplicate part IDs")
        previous = {}
        item_skills = set()
        for part in parts:
            location = f"{where}.{part.get('id')}"
            require(re.fullmatch(r"[a-z][a-z0-9_]*", part.get("id", "")), f"{location}: invalid part ID")
            localized(part.get("prompt"), location + ".prompt")
            require(finite(part.get("maxPoints")) and part["maxPoints"] > 0, f"{location}: positive points required")
            skills = part.get("competencyIds", [])
            require(isinstance(skills, list) and skills and len(skills) == len(set(skills)) and set(skills).issubset(SKILLS), f"{location}: invalid skill evidence")
            require(all(catalog[skill]["domain"] == item["domain"] for skill in skills), f"{location}: domain does not match skill")
            item_skills.update(skills)
            answer = part.get("answer", {})
            expected_type = {"number": "number", "choice": "choice", "multiChoice": "set", "cells": "set", "order": "sequence", "text": "manual"}.get(part.get("kind"))
            require(expected_type and answer.get("type") == expected_type, f"{location}: answer type mismatch")
            option_ids = set()
            if part["kind"] in {"choice", "multiChoice", "order"}:
                options = part.get("options", [])
                require(isinstance(options, list) and len(options) >= 2, f"{location}: options required")
                option_ids = {option.get("id") for option in options}
                require(len(option_ids) == len(options) and all(isinstance(x, str) and x for x in option_ids), f"{location}: duplicate/empty option ID")
                for option in options:
                    localized(option.get("label"), location + ".option")
            if expected_type == "number":
                require(finite(answer.get("value")), f"{location}: finite number answer required")
                require(finite(answer.get("tolerance", 0)) and answer.get("tolerance", 0) >= 0, f"{location}: invalid tolerance")
                if "unit" in part:
                    require(isinstance(part["unit"], str) and bool(part["unit"]), f"{location}: explicit unit required")
            elif expected_type == "choice":
                require(answer.get("value") in option_ids, f"{location}: correct option missing")
            elif expected_type in {"set", "sequence"}:
                values = answer.get("values")
                require(isinstance(values, list) and all(isinstance(v, str) for v in values), f"{location}: string-list answer required")
                require(len(values) == len(set(values)), f"{location}: duplicate answer entry")
                if part["kind"] == "cells":
                    fig = part.get("figure", {})
                    require(fig.get("kind") in {"grid", "mirror", "cubeNet"}, f"{location}: grid figure required for cells")
                    data = fig["data"]
                    coordinates(values, location, data["rows"], data["cols"])
                    given = set(data.get("cells", data.get("filled", [])))
                    require(not given.intersection(values), f"{location}: cells answer must contain additions only")
                else:
                    require(set(values).issubset(option_ids), f"{location}: answer refers to missing option")
                    if expected_type == "sequence":
                        require(set(values) == option_ids, f"{location}: order must include each option exactly once")
            elif expected_type == "manual":
                localized(answer.get("criteria"), location + ".criteria")
                require(isinstance(part.get("rubric"), list) and part["rubric"], f"{location}: manual rubric required")
                for criterion in part["rubric"]:
                    localized(criterion, location + ".rubric")
            if "figure" in part:
                validate_figure(part["figure"], location + ".figure")
            if "carryFrom" in part:
                source = previous.get(part["carryFrom"])
                require(expected_type == "number" and source and source["kind"] == "number", f"{location}: carry must reference previous number part")
                offset = part.get("carryOffset")
                require(finite(offset) and math.isclose(source["answer"]["value"] + offset, answer["value"], abs_tol=1e-9), f"{location}: inconsistent carry arithmetic")
            for wrong in part.get("errors", []):
                require(isinstance(wrong.get("value"), str) and wrong["value"], f"{location}: error value must be a string")
                require(re.fullmatch(r"[a-z][a-z0-9_]*", wrong.get("code", "")), f"{location}: misconception code required")
                localized(wrong.get("feedback"), location + ".error.feedback")
                if expected_type == "number":
                    require(not math.isclose(float(wrong["value"]), answer["value"], abs_tol=max(answer.get("tolerance", 0), 1e-9)), f"{location}: error example is actually correct")
                if expected_type == "choice":
                    require(wrong["value"] in option_ids and wrong["value"] != answer["value"], f"{location}: invalid wrong option")
            previous[part["id"]] = part
        require(set(item["source"].get("referenceCompetencies", [])) == item_skills, f"{where}: provenance skills inconsistent")
        for skill in item_skills:
            coverage[skill][item["use"]] += 1
    require(all(len(uses) == 1 for uses in families.values()), "a task family crosses practice/check/rehearsal partitions")
    if complete:
        require(len(tasks) >= 128, "complete pack requires at least 128 items")
        for skill in SKILLS:
            require(coverage[skill]["practice"] >= 2 and coverage[skill]["check"] >= 1 and coverage[skill]["rehearsal"] >= 1,
                    f"{skill}: insufficient practice/check/rehearsal coverage")
        if tuple(map(int, package["version"].split("."))) >= (2, 1, 0):
            try:
                verify_compatibility(package)
            except ValueError as error:
                raise ContentError(str(error)) from error
    return {"competencies": len(competencies), "tasks": len(tasks), "parts": sum(len(t["parts"]) for t in tasks),
            "modes": dict(Counter(t["use"] for t in tasks)), "domains": dict(Counter(t["domain"] for t in tasks))}


def main():
    package = json.loads(ASSET.read_text(encoding="utf-8"))
    print(json.dumps(validate_package(package), sort_keys=True))


if __name__ == "__main__":
    main()
