"""Convert the kompass4 mathematics export into NumberNebula's task format.

kompass4 (https://github.com/CrispStrobe/kompass4) owns six original 45-minute
practice papers and their interactive answer companions. Its exporter
(`python -m kompass.export_interactive_math`) writes a bundle plus PNG
diagrams rendered by the print renderer. This tool keeps that export pinned
under `tool/kompass/kompass4_math_source.json` and converts it into
`assets/kompass/kompass4/math_original.json` (tasks with use `original`).

    python3 -B tool/kompass/import_kompass4_math.py --source EXPORT.json --figures EXPORT_FIGURES/
    python3 -B tool/kompass/import_kompass4_math.py            # rebuild from the pinned source
    python3 -B tool/kompass/import_kompass4_math.py --check    # byte-for-byte check

The tasks stay German; the English fields repeat the German text so the
bilingual model can load them. Answers are never derived here: every part
comes from the companion's explicit answer contract.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tool/kompass/kompass4_math_source.json"
OUTPUT = ROOT / "assets/kompass/kompass4/math_original.json"
FIGURES = ROOT / "assets/kompass/kompass4/figures"
ASSET_PREFIX = "assets/kompass/kompass4/"
VERSION = "1.0.0"
SKIPPED_BLOCKS = {"response", "calculation_grid", "space", "choice"}


def plain(text):
    text = re.sub(r"<br\s*/?>", "\n", str(text))
    return html.unescape(re.sub(r"<[^>]+>", "", text)).strip()


def both(text):
    return {"de": text, "en": text}


def words(text):
    return set(re.findall(r"[0-9A-Za-zÄÖÜäöüß]+", text.lower()))


def item(block):
    """One stem/solution block as a figure item, or None when not shown."""
    kind = block["type"]
    if kind == "paragraph":
        return {"kind": "text", "data": {"text": plain(block["text"])}}
    if kind == "table":
        return {"kind": "table", "data": {
            "headers": [plain(h) for h in block.get("headers", [])],
            "rows": [[plain(c) for c in row] for row in block["rows"]]}}
    if kind == "figure":
        if "asset" not in block:
            raise SystemExit(f"figure {block['kind']} was exported without an image; pass --figures")
        return {"kind": "image", "alt": both(block.get("alt", "")), "data": {
            "asset": ASSET_PREFIX + block["asset"], "width": block["width"],
            "height": block["height"], "widthCm": block.get("widthCm") or 16}}
    return None


def stack(items):
    if not items:
        return None
    if len(items) == 1 and items[0]["kind"] != "text":
        only = dict(items[0])
        only.setdefault("alt", both(""))
        return only
    alt = " ".join(i["alt"]["de"] for i in items if i.get("alt") and i["alt"]["de"])
    return {"kind": "stack", "data": {"items": items}, "alt": both(alt)}


def convert_part(part, rubric):
    kind = part["type"]
    criteria = both("\n".join(part["rubric"]))
    out = {"id": part["id"], "prompt": both(plain(part["prompt"])),
           "competencyIds": part["competencyIds"], "maxPoints": part["maxPoints"],
           "rubric": [both(r) for r in part["rubric"]]}
    if kind == "number":
        values = [float(a.replace(".", "").replace(",", ".")) if re.fullmatch(r"\d{1,3}(\.\d{3})+", a)
                  else float(a.replace(",", ".")) for a in part["answers"]]
        values = [int(v) if v == int(v) else v for v in values]
        out.update(kind="number", unit=part.get("unit") or part.get("label", ""),
                   answer={"type": "number", "value": values[0], "accepted": values[1:]})
    elif kind == "text":
        out.update(kind="text", answer={"type": "text", "values": part["answers"],
                                        "caseSensitive": part.get("caseSensitive", False),
                                        "reviewOnMismatch": part.get("reviewOnMismatch", False),
                                        "criteria": criteria})
    elif kind in {"singleChoice", "multiChoice", "order"}:
        out["options"] = [{"id": o["id"], "label": both(plain(o["text"]))} for o in part["options"]]
        if kind == "singleChoice":
            out.update(kind="choice", answer={"type": "choice", "value": part["answers"][0]})
        elif kind == "multiChoice":
            out.update(kind="multiChoice", answer={"type": "set", "values": part["answers"]})
        else:
            out.update(kind="order", answer={"type": "sequence", "values": part["answers"]})
    else:  # review
        out.update(kind="text", answer={"type": "manual", "criteria": criteria,
                                        "creditSteps": part.get("creditSteps", [0, part["maxPoints"]])})
    if part.get("followOnFrom"):
        out["answer"]["followOnFrom"] = part["followOnFrom"]
    return out


def convert(source):
    tasks, papers = [], []
    for test in source["tests"]:
        task_ids = []
        for original in (t for t in source["tasks"] if t["testId"] == test["id"]):
            parts = [convert_part(p, original["rubric"]) for p in original["parts"]]
            prompts = [words(plain(p["prompt"])) for p in original["parts"]]
            items = []
            for block in original["blocks"]:
                if block["type"] in SKIPPED_BLOCKS:
                    continue
                if block["type"] == "paragraph":
                    text = words(plain(block["text"]))
                    # A sub-question repeated verbatim in its answer part is shown once.
                    if text and any(text <= prompt for prompt in prompts):
                        continue
                shown = item(block)
                if shown:
                    items.append(shown)
            first = items.pop(0)["data"]["text"] if items and items[0]["kind"] == "text" else original["title"]
            solution_text = "\n".join(
                plain(b["text"]) if b["type"] == "paragraph" else
                "\n".join(" | ".join(plain(c) for c in row) for row in b["rows"])
                for b in original["solutionBlocks"] if b["type"] in {"paragraph", "table"})
            solution_figures = [item(b) for b in original["solutionBlocks"] if b["type"] == "figure"]
            task_id = "k4_" + original["id"]
            task = {
                "id": task_id, "familyId": task_id, "domain": original["domain"],
                "title": both(original["title"]), "prompt": both(first),
                "level": 2, "use": "original", "paperId": test["id"],
                "parts": parts,
                "hints": [both(h) for h in original["hints"]],
                "solution": both(solution_text or original["title"]),
                "estimatedSeconds": original["estimatedSeconds"],
                "source": {**original["source"], "kind": "project-original",
                           "license": "kompass4 project material; no open licence declared (see kompass4 LICENSING.md)",
                           "taskId": original["id"]},
            }
            figure = stack(items)
            if figure:
                task["figure"] = figure
            solution_figure = stack(solution_figures)
            if solution_figure:
                task["solutionFigure"] = solution_figure
            tasks.append(task)
            task_ids.append(task_id)
        papers.append({
            "id": test["id"], "title": test["title"], "taskIds": task_ids,
            "totalPoints": test["totalPoints"], "totalSeconds": test["timing"]["totalSeconds"],
            "printUrl": test["printUrl"], "solutionsUrl": test["solutionsUrl"],
            "instructions": test["instructions"], "materials": test.get("materials", []),
        })
    return {
        "schemaVersion": 1, "id": "kompass4_math_original", "version": VERSION,
        "language": "de",
        "source": {**source["source"], "title": source["title"],
                   "limitations": source["limitations"],
                   "sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest()},
        "tasks": tasks, "papers": papers,
    }


def render(source):
    return json.dumps(convert(source), ensure_ascii=False, indent=1) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", type=Path, help="a new kompass4 export to pin")
    parser.add_argument("--figures", type=Path, help="the export's figures directory")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if args.source:
        if not args.figures:
            parser.error("--figures is required with --source")
        SOURCE.write_bytes(args.source.read_bytes())
        if FIGURES.exists():
            shutil.rmtree(FIGURES)
        shutil.copytree(args.figures, FIGURES)
    source = json.loads(SOURCE.read_text("utf-8"))
    text = render(source)
    referenced = {i["data"]["asset"].removeprefix(ASSET_PREFIX + "figures/")
                  for i in re.finditer(r'"asset": "([^"]+)"', text) for i in [{"data": {"asset": i.group(1)}}]}
    present = {p.name for p in FIGURES.glob("*.png")}
    if referenced - present or present - referenced:
        sys.exit(f"figures out of sync: missing {sorted(referenced - present)}, unused {sorted(present - referenced)}")
    if args.check:
        if OUTPUT.read_text("utf-8") != text:
            sys.exit(f"{OUTPUT.relative_to(ROOT)} is stale; run tool/kompass/import_kompass4_math.py")
        print("kompass4 papers up to date")
        return
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(text, "utf-8")
    data = json.loads(text)
    print(f"Wrote {len(data['tasks'])} tasks in {len(data['papers'])} papers, {len(present)} figures")


if __name__ == "__main__":
    main()
