#!/usr/bin/env python3
"""Build standalone print worksheets and separate keys from math_v2.json.

No solution payload is embedded in a learner worksheet. Figures are precise
inline SVG; physical ruler tasks explicitly require a separate paper drawing.
"""
from __future__ import annotations

import argparse
import html
import json
import math
from pathlib import Path

from validate_content import validate_package

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "assets/kompass/math_v2.json"
OUTPUT = ROOT / "assets/kompass/print"
DOMAINS = {
    "numbers": {"de": "Zahlen und Operationen", "en": "Numbers and operations"},
    "geometry": {"de": "Raum und Form", "en": "Space and shape"},
    "measurement": {"de": "Größen und Messen", "en": "Quantities and measurement"},
    "data": {"de": "Daten und Zufall", "en": "Data and chance"},
}
# An authored balanced form, not an official item/point blueprint. The remaining
# rehearsal families stay available to the app without entering practice output.
REHEARSAL_IDS = [
    "mz01_missing_bundle_count", "mz02_missing_comparison_digit",
    "mz04_subtraction_audit", "mz05_quarter_hundred_groups",
    "mz07_near_thousand_correction", "mz08_invariant_sum_pattern",
    "mz09_best_pair_below_limit", "mz10_insufficient_information",
    "mr02_join_identical_rectangles", "mr03_combine_half_squares",
    "mr05_triangle_axis_counterexample", "mr06_reverse_view_plans",
    "mr07_valid_net_selection",
    "mg01_implausible_label", "mg02_reconstruct_route_leg",
    "mg04_reverse_receipt", "mg05_timetable_with_walk",
    "md01_table_constraints", "md04_draw_two_without_replacement",
    "md05_fair_number_card_rules",
]


def tr(value, language):
    return str(value[language] if isinstance(value, dict) else value)


def esc(value):
    return html.escape(str(value), quote=True)


def number_text(value, language):
    text = f"{value:g}"
    return text.replace(".", ",") if language == "de" else text


def svg_text(x, y, value, size=13, *, anchor="middle", weight="normal"):
    return f'<text x="{x:g}" y="{y:g}" text-anchor="{anchor}" font-size="{size:g}" font-weight="{weight}">{esc(value)}</text>'


def svg_line(x1, y1, x2, y2, *, dashed=False, width=1.4):
    dash = ' stroke-dasharray="5 4"' if dashed else ""
    return f'<line x1="{x1:g}" y1="{y1:g}" x2="{x2:g}" y2="{y2:g}" stroke="#27333c" stroke-width="{width:g}"{dash}/>'


def svg_rect(x, y, width, height, fill="white", *, stroke="#27333c"):
    return f'<rect x="{x:g}" y="{y:g}" width="{width:g}" height="{height:g}" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>'


def svg_wrapper(width, height, alt, content):
    return (f'<svg class="diagram" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:g} {height:g}" '
            f'role="img" aria-label="{esc(alt)}"><title>{esc(alt)}</title>'
            f'<g font-family="Arial, Helvetica, sans-serif" fill="#17242e">{content}</g></svg>')


def _cell(value):
    return tuple(map(int, value.split(",")))


def render_figure(fig, language, *, additions=(), response=False):
    kind, data = fig["kind"], fig["data"]
    alt = tr(fig["alt"], language)
    content = []
    if kind == "table":
        head = "".join(f"<th>{esc(tr(cell, language))}</th>" for cell in data["headers"])
        rows = "".join("<tr>" + "".join(f"<td>{esc(tr(cell, language))}</td>" for cell in row) + "</tr>" for row in data["rows"])
        return f'<table class="data-table" aria-label="{esc(alt)}"><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table>'
    if kind in {"grid", "mirror", "cubeNet"}:
        rows, cols, unit, pad = data["rows"], data["cols"], 28, 25
        given = set(data.get("filled", data.get("cells", [])))
        additions = set(additions)
        for row in range(rows):
            for col in range(cols):
                key = f"{row},{col}"
                if kind != "cubeNet" or response or key in given or key in additions:
                    fill = "#aebbc4" if key in given else ("#406b66" if key in additions else "white")
                    stroke = "#27333c" if key in given or kind != "cubeNet" else "#9aa5ae"
                    content.append(svg_rect(pad + col * unit, pad + row * unit, unit, unit, fill, stroke=stroke))
                if key in data.get("labels", {}):
                    content.append(svg_text(pad + (col + .5) * unit, pad + (row + .66) * unit, tr(data["labels"][key], language), 14, weight="bold"))
                if key in additions:
                    content.append(svg_text(pad + (col + .5) * unit, pad + (row + .68) * unit, "+", 16, weight="bold"))
        if response:
            for row in range(rows):
                content.append(svg_text(pad - 10, pad + (row + .66) * unit, row + 1, 10))
            for col in range(cols):
                content.append(svg_text(pad + (col + .5) * unit, pad - 8, col + 1, 10))
        if kind == "mirror":
            axis = data["axis"]
            if axis["direction"] == "vertical":
                x = pad + axis["at"] * unit
                content.append(svg_line(x, pad - 8, x, pad + rows * unit + 8, dashed=True, width=2.2))
            else:
                y = pad + axis["at"] * unit
                content.append(svg_line(pad - 8, y, pad + cols * unit + 8, y, dashed=True, width=2.2))
        return svg_wrapper(cols * unit + 2 * pad, rows * unit + 2 * pad, alt, "".join(content))
    if kind == "shapeComparison":
        shapes = data["shapes"]
        # One common geometry scale is essential for area comparisons.
        all_cells = [_cell(cell) for shape in shapes for cell in shape["cells"]]
        rows = max(r for r, _ in all_cells) + 1
        cols = max(c for _, c in all_cells) + 1
        unit, pad = 23, 18
        panel_width = cols * unit + 2 * pad
        for index, shape in enumerate(shapes):
            x0 = index * panel_width + pad
            content.append(svg_text(index * panel_width + panel_width / 2, 16, shape["id"], 15, weight="bold"))
            for row, col in map(_cell, shape["cells"]):
                content.append(svg_rect(x0 + col * unit, 30 + row * unit, unit, unit, "#c4ced5"))
        return svg_wrapper(len(shapes) * panel_width, rows * unit + 48, alt, "".join(content))
    if kind == "wall":
        rows, unit_w, unit_h, pad = data["rows"], 82, 34, 14
        count = len(rows)
        for row, values in enumerate(rows):
            for col, value in enumerate(values):
                x = pad + row * unit_w / 2 + col * unit_w
                y = pad + (count - row - 1) * unit_h
                content.append(svg_rect(x, y, unit_w, unit_h))
                if value is not None:
                    content.append(svg_text(x + unit_w / 2, y + 23, number_text(value, language), 16))
        return svg_wrapper(count * unit_w + pad * 2, count * unit_h + pad * 2, alt, "".join(content))
    if kind == "numberLine":
        low, high, step = data["min"], data["max"], data["step"]
        x = lambda value: 28 + (value - low) / (high - low) * 450
        content.append(svg_line(28, 46, 478, 46, width=1.8))
        for index in range(round((high - low) / step) + 1):
            value = low + index * step
            content.append(svg_line(x(value), 39, x(value), 53))
        content.append(svg_text(28, 75, number_text(low, language)))
        content.append(svg_text(478, 75, number_text(high, language)))
        for mark in data.get("marks", []):
            content.append(f'<circle cx="{x(mark["value"]):g}" cy="46" r="3.6"/>')
            content.append(svg_text(x(mark["value"]), 24, tr(mark["label"], language), 16, weight="bold"))
        return svg_wrapper(506, 91, alt, "".join(content))
    if kind == "placeValue":
        columns, width = data["columns"], 85
        for index, column in enumerate(columns):
            content.append(svg_rect(12 + index * width, 10, width, 35, "#eef1f4"))
            content.append(svg_rect(12 + index * width, 45, width, 47))
            content.append(svg_text(12 + (index + .5) * width, 34, tr(column["label"], language), 18, weight="bold"))
            content.append(svg_text(12 + (index + .5) * width, 77, column["value"], 23))
        return svg_wrapper(len(columns) * width + 24, 104, alt, "".join(content))
    if kind == "barChart":
        maximum, step = data["max"], data["step"]
        left, top, plot_width, plot_height, baseline = 52, 26, 370, 150, 176
        count = len(data["values"])
        for index in range(round(maximum / step) + 1):
            value = index * step
            y = baseline - value / maximum * plot_height
            content.append(svg_line(left, y, left + plot_width, y, width=.6))
            content.append(svg_text(left - 10, y + 4, number_text(value, language), 11, anchor="end"))
        content.append(svg_line(left, top, left, baseline, width=1.7))
        content.append(svg_line(left, baseline, left + plot_width, baseline, width=1.7))
        for index, (name, value) in enumerate(zip(data["labels"], data["values"])):
            slot = plot_width / count
            x = left + slot * (index + .23)
            height = value / maximum * plot_height
            content.append(svg_rect(x, baseline - height, slot * .54, height, "#aebfc9"))
            content.append(svg_text(left + slot * (index + .5), baseline + 22, tr(name, language), 12))
        if "yLabel" in data:
            content.append(svg_text(left, 15, tr(data["yLabel"], language), 11, anchor="start"))
        return svg_wrapper(450, 211, alt, "".join(content))
    if kind == "cubePlan":
        heights, unit, pad = data["heights"], 38, 45
        rows, cols = len(heights), len(heights[0])
        content.append(svg_text(pad + cols * unit / 2, 18, "hinten" if language == "de" else "back", 12))
        for row, values in enumerate(heights):
            for col, value in enumerate(values):
                content.append(svg_rect(pad + col * unit, 30 + row * unit, unit, unit, "#eef1f4"))
                content.append(svg_text(pad + (col + .5) * unit, 30 + (row + .66) * unit, value, 18, weight="bold"))
        content.append(svg_text(pad + cols * unit / 2, 48 + rows * unit, "vorne" if language == "de" else "front", 12))
        if data["view"] == "front":
            x, y = pad + cols * unit / 2, 54 + rows * unit
            content.extend([svg_line(x, y + 28, x, y + 5, width=2), svg_line(x, y + 5, x - 5, y + 13), svg_line(x, y + 5, x + 5, y + 13)])
        else:
            x, y = pad + cols * unit + 8, 30 + rows * unit / 2
            content.extend([svg_line(x + 26, y, x + 3, y, width=2), svg_line(x + 3, y, x + 11, y - 5), svg_line(x + 3, y, x + 11, y + 5)])
            content.append(svg_text(x + 16, y + 22, "rechts" if language == "de" else "right", 10))
        return svg_wrapper(cols * unit + 2 * pad + 18, rows * unit + 95, alt, "".join(content))
    if kind == "clock":
        cx, cy, radius = 90, 90, 72
        content.append(f'<circle cx="{cx}" cy="{cy}" r="{radius}" fill="white" stroke="#27333c" stroke-width="2"/>')
        for value in range(1, 13):
            angle = math.radians(value * 30 - 90)
            content.append(svg_text(cx + math.cos(angle) * 58, cy + math.sin(angle) * 58 + 4, value, 13))
        for angle, length, width in [(data["minute"] * 6 - 90, 50, 2), ((data["hour"] % 12 + data["minute"] / 60) * 30 - 90, 35, 4)]:
            radians = math.radians(angle)
            content.append(svg_line(cx, cy, cx + math.cos(radians) * length, cy + math.sin(radians) * length, width=width))
        content.append(f'<circle cx="{cx}" cy="{cy}" r="3"/>')
        return svg_wrapper(180, 180, alt, "".join(content))
    if kind == "tokenBag":
        tokens = [tr(item["label"], language) for item in data["tokens"] for _ in range(item["count"])]
        columns, size = min(6, len(tokens)), 58
        rows = math.ceil(len(tokens) / columns)
        for index, token in enumerate(tokens):
            x, y = 32 + index % columns * size, 32 + index // columns * size
            content.append(f'<circle cx="{x:g}" cy="{y:g}" r="24" fill="#eef1f4" stroke="#27333c" stroke-width="1.3"/>')
            content.append(svg_text(x, y + 4, token, 10 if len(token) > 4 else 12))
        return svg_wrapper(columns * size + 6, rows * size + 6, alt, "".join(content))
    if kind == "spinner":
        sectors, cx, cy, radius = data["sectors"], 93, 93, 75
        total, start = sum(item["weight"] for item in sectors), -math.pi / 2
        for index, sector in enumerate(sectors):
            end = start + 2 * math.pi * sector["weight"] / total
            x1, y1 = cx + radius * math.cos(start), cy + radius * math.sin(start)
            x2, y2 = cx + radius * math.cos(end), cy + radius * math.sin(end)
            large = int(end - start > math.pi)
            fill = "#e3e8ec" if index % 2 == 0 else "white"
            content.append(f'<path d="M {cx},{cy} L {x1:g},{y1:g} A {radius},{radius} 0 {large},1 {x2:g},{y2:g} Z" fill="{fill}" stroke="#27333c" stroke-width="1.2"/>')
            middle = (start + end) / 2
            content.append(svg_text(cx + 48 * math.cos(middle), cy + 48 * math.sin(middle) + 4, tr(sector["label"], language), 12, weight="bold"))
            start = end
        content.append(f'<circle cx="{cx}" cy="{cy}" r="3"/>')
        return svg_wrapper(186, 186, alt, "".join(content))
    if kind == "measureLine":
        start, end, step = data["start"], data["end"], data["step"]
        x = lambda value: 25 + (value - start) / (end - start) * 390
        content.append(svg_line(25, 30, 415, 30, width=2))
        for index in range(round((end - start) / step) + 1):
            value = start + index * step
            content.append(svg_line(x(value), 23, x(value), 40))
            content.append(svg_text(x(value), 61, number_text(value, language), 12))
        content.append(svg_text(434, 61, data["unit"], 12))
        return svg_wrapper(455, 79, alt, "".join(content))
    if kind == "polygon":
        points = data["points"]
        min_x, max_x = min(x for x, _ in points), max(x for x, _ in points)
        min_y, max_y = min(y for _, y in points), max(y for _, y in points)
        scale = min(240 / (max_x - min_x or 1), 115 / (max_y - min_y or 1))
        mapped = [(20 + (x - min_x) * scale, 20 + (max_y - y) * scale) for x, y in points]
        points_string = " ".join(f"{x:g},{y:g}" for x, y in mapped)
        content.append(f'<polygon points="{points_string}" fill="#eef1f4" stroke="#27333c" stroke-width="1.8"/>')
        for index, name in enumerate(data.get("labels", [])):
            x, y = mapped[index]
            content.append(svg_text(x, y - 7, tr(name, language), 12))
        return svg_wrapper(40 + (max_x - min_x) * scale, 40 + (max_y - min_y) * scale, alt, "".join(content))
    raise ValueError(f"Unsupported print figure: {kind}")


CSS = """
@page { size: A4; margin: 16mm 17mm 17mm; }
* { box-sizing: border-box; }
body { max-width: 820px; margin: 0 auto; padding: 24px; color: #17242e; background: white;
       font-family: Arial, Helvetica, sans-serif; font-size: 15px; line-height: 1.4; }
h1 { font-size: 29px; line-height: 1.15; margin: 10px 0; }
h2 { font-size: 19px; margin: 0 0 8px; line-height: 1.3; }
h3 { font-size: 16px; margin: 12px 0 6px; }
p { margin: 6px 0 10px; }
.eyebrow { text-transform: uppercase; letter-spacing: .1em; font-size: 11px; font-weight: bold; color: #45616c; }
.intro { border: 1px solid #c3cdd3; border-left: 4px solid #416c69; padding: 14px 16px; margin: 18px 0; }
.warning { font-size: 13px; color: #364b57; }
.name { margin: 22px 0; }
.toolbar { display: flex; gap: 12px; flex-wrap: wrap; align-items: center; padding: 12px 0; margin-bottom: 14px; }
button, select { font: inherit; background: #eef2f4; border: 1px solid #9dadb8; border-radius: 6px; padding: 8px 12px; }
.domain-title { font-size: 24px; margin: 30px 0 14px; border-bottom: 2px solid #416c69; padding-bottom: 6px; }
.task { margin: 0 0 22px; padding: 15px 0 16px; border-bottom: 1px solid #c7d0d7; break-inside: avoid; page-break-inside: avoid; }
.task h2 span { font-size: 11px; font-weight: normal; color: #546572; margin-left: 8px; white-space: nowrap; }
.part { margin-top: 12px; }
.part-prompt { font-weight: 600; }
.points { font-size: 11px; font-weight: normal; color: #526472; }
.response { display: flex; align-items: baseline; gap: 9px; margin: 16px 0 5px; }
.number-line { display: inline-block; width: 160px; border-bottom: 1px solid #4b5b65; height: 20px; }
.writing-line { height: 27px; border-bottom: 1px solid #9caab4; }
.choices { list-style: none; margin: 5px 0; padding: 0; }
.choices li { display: flex; gap: 8px; margin: 6px 0; align-items: baseline; }
.box { display: inline-block; border: 1px solid #4b5b65; width: 13px; height: 13px; flex: 0 0 13px; }
.order-box { width: 24px; height: 20px; }
.diagram { display: block; width: 100%; height: auto; max-width: 100%; max-height: 185px; margin: 10px auto; }
.data-table, .score-table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; }
th, td { border: 1px solid #7d909d; padding: 7px 9px; text-align: left; vertical-align: top; }
th { background: #eef2f4; font-weight: 600; }
.solution { padding: 9px 12px; background: #f0f5f2; border-left: 3px solid #416c69; }
.rubric { margin: 6px 0 10px; padding-left: 22px; font-size: 13px; }
.source { font-size: 11px; color: #53646f; overflow-wrap: anywhere; }
.review-sheet { break-before: page; page-break-before: always; }
footer { margin-top: 24px; border-top: 1px solid #c7d0d7; padding-top: 8px; font-size: 11px; color: #53646f; }
[hidden] { display: none !important; }
@media print {
  body { padding: 0; max-width: none; font-size: 10.5pt; }
  h1 { font-size: 22pt; } h2 { font-size: 13pt; }
  .screen-only { display: none !important; }
  .intro { padding: 9px 12px; }
  .task { margin-bottom: 12px; padding-top: 10px; }
  .domain-title { break-before: page; page-break-before: always; font-size: 17pt; }
  .diagram { max-height: 44mm; }
  .data-table, .score-table { font-size: 9.5pt; }
  th, td { padding: 5px 7px; }
  a { color: inherit; text-decoration: none; }
  .solution { background: white; }
}
"""


def answer_text(part, language):
    answer = part["answer"]
    if answer["type"] == "number":
        return number_text(answer["value"], language) + (f' {part["unit"]}' if part.get("unit") else "")
    if answer["type"] == "manual":
        return tr(answer["criteria"], language)
    labels = {option["id"]: tr(option["label"], language) for option in part.get("options", [])}
    if answer["type"] == "choice":
        return labels[answer["value"]]
    if part["kind"] == "cells":
        return "; ".join((f"Reihe {row + 1}, Spalte {col + 1}" if language == "de" else f"row {row + 1}, column {col + 1}") for row, col in sorted(map(_cell, answer["values"])))
    separator = " → " if answer["type"] == "sequence" else "; "
    return separator.join(labels[value] for value in answer["values"])


def render_task(item, index, language, solutions):
    de = language == "de"
    points = sum(part["maxPoints"] for part in item["parts"])
    html_parts = [f'<article class="task" data-task-id="{item["id"]}" data-domain="{item["domain"]}">',
                  f'<h2>{index}. {esc(tr(item["title"], language))}<span>{number_text(points, language)} {"Punkte" if de else "points"}</span></h2>',
                  f'<p>{esc(tr(item["prompt"], language))}</p>']
    if "figure" in item:
        html_parts.append(render_figure(item["figure"], language))
    for number, part in enumerate(item["parts"], 1):
        html_parts.append(f'<section class="part"><p class="part-prompt">{chr(96 + number)}) {esc(tr(part["prompt"], language))} '
                          f'<span class="points">({number_text(part["maxPoints"], language)} {"P." if de else "pt"})</span></p>')
        if "figure" in part:
            html_parts.append(render_figure(part["figure"], language,
                                           additions=part["answer"].get("values", []) if solutions and part["kind"] == "cells" else (),
                                           response=part["kind"] == "cells"))
        if solutions:
            html_parts.append(f'<p class="solution"><strong>{"Bewertung" if de else "Marking"}:</strong> {esc(answer_text(part, language))}</p>')
            if part.get("rubric"):
                html_parts.append('<ul class="rubric">' + "".join(f"<li>{esc(tr(row, language))}</li>" for row in part["rubric"]) + "</ul>")
            if part.get("carryFrom"):
                source = next(i + 1 for i, candidate in enumerate(item["parts"]) if candidate["id"] == part["carryFrom"])
                offset = ("− " if part["carryOffset"] < 0 else "+ ") + number_text(abs(part["carryOffset"]), language)
                text = (f"Folgefehler separat markieren: eigener Wert aus Teil {chr(96 + source)}) "
                        f"{offset}; nicht als unabhängige vollständig richtige Lösung zählen." if de else
                        f"Record carried-error credit separately: own value from part {chr(96 + source)}) "
                        f"{offset}; do not count it as an independently fully correct solution.")
                if part.get("unit") == "€":
                    text += (" Beide eigenen Geldbeträge müssen nichtnegativ und in vollen Cent angegeben sein." if de else
                             " Both own money amounts must be nonnegative and expressed in whole cents.")
                elif float(part["answer"]["value"]).is_integer():
                    text += (" Beide eigenen Angaben müssen nichtnegative ganze Zahlen sein." if de else
                             " Both own answers must be nonnegative whole numbers.")
                else:
                    text += (" Beide eigenen Angaben müssen nichtnegativ sein." if de else
                             " Both own answers must be nonnegative.")
                html_parts.append(f'<p class="warning">{esc(text)}</p>')
        elif part["kind"] in {"choice", "multiChoice", "order"}:
            label_text = ("Alle passenden ankreuzen." if de else "Select every matching option.") if part["kind"] == "multiChoice" else (("Reihenfolge mit Zahlen eintragen." if de else "Number the options in order.") if part["kind"] == "order" else ("Genau eine Antwort ankreuzen." if de else "Select exactly one answer."))
            html_parts.append(f'<p class="points">{label_text}</p><ul class="choices">')
            for option in part["options"]:
                box = "box order-box" if part["kind"] == "order" else "box"
                html_parts.append(f'<li><span class="{box}"></span><span>{esc(tr(option["label"], language))}</span></li>')
            html_parts.append("</ul>")
        elif part["kind"] == "number":
            html_parts.append(f'<div class="response"><span class="number-line"></span><span>{esc(part.get("unit", ""))}</span></div>')
        elif part["kind"] == "text":
            html_parts.append('<div class="writing-line"></div>' * (4 if part["maxPoints"] >= 2 else 3))
        html_parts.append("</section>")
    if solutions:
        html_parts.append(f'<p><strong>{"Lösungsweg" if de else "Worked solution"}:</strong> {esc(tr(item["solution"], language))}</p>')
        skills = sorted({skill for part in item["parts"] for skill in part["competencyIds"]})
        html_parts.append(f'<p class="source">{esc(item["id"])} · {", ".join(skills)} · {"Originalaufgabe" if de else "Original task"}</p>')
    html_parts.append("</article>")
    return "\n".join(html_parts)


def render_document(package, selected, mode, language, *, solutions=False):
    de = language == "de"
    mode_name = ("Übungssammlung" if mode == "practice" else "45-Minuten-Probe") if de else ("Practice collection" if mode == "practice" else "45-minute rehearsal")
    suffix = (" — Lösungen und Auswertung" if de else " — Solutions and review") if solutions else ""
    title = f"NumberNebula · {mode_name}{suffix}"
    intro = ("Diese eigenständigen Aufgaben gehören zum optionalen KOMPASS-4-Mathematik-Lernpfad. Sie sind kein amtlicher Test. Aus Punkten folgt keine amtliche Niveaustufe oder Schulartempfehlung." if de else
             "These original exercises belong to the optional KOMPASS 4 mathematics pathway. This is not an official test. Points do not establish an official proficiency level or school recommendation.")
    timing = ("Nach dem Lesen der allgemeinen Hinweise beginnen 45 Minuten Arbeitszeit, einschließlich Aufgabenlesen und Kontrolle. Aufgaben dürfen übersprungen und später bearbeitet werden. Lösungen erst nach Abgabe ansehen." if de else
              "After reading the general instructions, begin 45 minutes of work, including reading the tasks and checking answers. You may skip tasks and return later. Open solutions only after submission.")
    practice = ("Wähle einen Bereich oder einige Aufgaben für eine ruhige Übung. Es gibt hier keine Zeitvorgabe. Halte genutzte Hilfe getrennt vom ersten eigenen Versuch fest." if de else
                "Choose a domain or a few tasks for unhurried practice. There is no time limit. Record any help separately from the first independent attempt.")
    materials = ("Material: Papier, Bleistift, Radiergummi und Lineal. Ohne Taschenrechner. Maße an Zeichnungen gelten nach Beschriftung; Bildschirmbilder nicht mit einem echten Lineal messen." if de else
                 "Materials: paper, pencil, eraser and ruler. No calculator. Use labelled dimensions; do not measure screen images with a physical ruler.")
    review_note = ("Teilaufgaben unabhängig bewerten. Gleichwertige Erklärungen zulassen. Nicht bearbeitet, Rechenfehler, Folgefehler und genutzte Hilfe getrennt festhalten. Offene Texte und Papierzeichnungen bleiben bis zur Prüfung unbewertet. Ein korrektes Ergebnis allein belegt nicht jeden Lösungsweg." if de else
                   "Mark parts independently and accept equivalent explanations. Distinguish not attempted, calculation errors, carried errors and assistance. Open text and paper drawings remain unreviewed until checked. A correct answer alone does not establish every reasoning step.")
    options = '<option value="all">' + ("Alle Bereiche" if de else "All domains") + "</option>" + "".join(f'<option value="{key}">{esc(value[language])}</option>' for key, value in DOMAINS.items())
    body = [f'<!doctype html><html lang="{language}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
            f'<title>{esc(title)}</title><style>{CSS}</style></head><body>',
            '<div class="toolbar screen-only"><button type="button" onclick="window.print()">' + ("Drucken / als PDF speichern" if de else "Print / save as PDF") + '</button>'
            f'<label for="domain-filter">{"Bereich" if de else "Domain"}:</label><select id="domain-filter">{options}</select></div>',
            '<div class="eyebrow">NumberNebula · KOMPASS 4 ' + ("Mathematik" if de else "Mathematics") + '</div>',
            f'<h1>{esc(mode_name + suffix)}</h1><p>{len(selected)} {"Aufgaben" if de else "tasks"} · {"Deutsch" if de else "English"} · {esc(package["version"])}</p>',
            f'<div class="intro"><p>{esc(intro)}</p><p><strong>{esc(timing if mode == "rehearsal" else practice)}</strong></p><p>{esc(materials)}</p></div>']
    if solutions:
        body.append(f'<p class="warning">{esc(review_note)}</p>')
    else:
        body.append('<p class="name">' + ("Name: ______________________________  Datum: ______________" if de else "Name: ______________________________  Date: ______________") + "</p>")
    current_domain = None
    for index, item in enumerate(selected, 1):
        if item["domain"] != current_domain:
            current_domain = item["domain"]
            body.append(f'<h2 class="domain-title" data-domain="{current_domain}">{esc(DOMAINS[current_domain][language])}</h2>')
        body.append(render_task(item, index, language, solutions))
    if solutions:
        body.append('<section class="review-sheet"><h2>' + ("Ergebnisse und nächste Schritte" if de else "Results and next steps") + "</h2>")
        headers = ["Nr.", "Kompetenzen", "Max.", "Erreicht", "Offen / Hilfe"] if de else ["No.", "Competencies", "Max.", "Earned", "Blank / help"]
        body.append('<table class="score-table"><thead><tr>' + "".join(f"<th>{esc(text)}</th>" for text in headers) + "</tr></thead><tbody>")
        for index, item in enumerate(selected, 1):
            skills = sorted({skill for part in item["parts"] for skill in part["competencyIds"]})
            points = sum(part["maxPoints"] for part in item["parts"])
            body.append(f'<tr data-domain="{item["domain"]}"><td>{index}</td><td>{", ".join(skills)}</td><td>{number_text(points, language)}</td><td></td><td></td></tr>')
        body.append("</tbody></table><p>" + ("Beobachtung und nächste Übung:" if de else "Observation and next practice:") + '</p><div class="writing-line"></div><div class="writing-line"></div></section>')
    body.append('<footer>' + ("Originale NumberNebula-Aufgaben · AGPL-3.0-only · Lernstandshinweise sind keine Testvorhersage." if de else
                             "Original NumberNebula tasks · AGPL-3.0-only · Practice evidence is not a test prediction.") + "</footer>")
    # Only presentation controls are embedded; there are no answers in the
    # learner HTML, in hidden markup, in JSON or in this script.
    body.append("""<script>
document.getElementById('domain-filter').addEventListener('change', function () {
  const selected = this.value;
  document.querySelectorAll('[data-domain]').forEach(function (element) {
    element.hidden = selected !== 'all' && element.dataset.domain !== selected;
  });
});
</script></body></html>""")
    return "\n".join(body) + "\n"


def build_outputs(package):
    validate_package(package)
    catalog = {task["id"]: task for task in package["tasks"]}
    practice = [task for task in package["tasks"] if task["use"] == "practice"]
    rehearsal = [catalog[id] for id in REHEARSAL_IDS]
    if any(task["use"] != "rehearsal" for task in rehearsal):
        raise ValueError("A print rehearsal references a non-rehearsal task")
    manifest = {"schemaVersion": 1, "worksheets": []}
    files = {}
    for mode, selected in [("practice", practice), ("rehearsal", rehearsal)]:
        worksheet = {"id": mode + "_v2", "mode": mode, "taskIds": [task["id"] for task in selected],
                     "files": {}, "solutions": {}}
        for language in ["de", "en"]:
            for solutions in [False, True]:
                filename = f"{mode}_{language}" + ("_solutions" if solutions else "") + ".html"
                files[filename] = render_document(package, selected, mode, language, solutions=solutions)
                worksheet["solutions" if solutions else "files"][language] = filename
        manifest["worksheets"].append(worksheet)
    files["manifest.json"] = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if any generated worksheet or manifest is stale.")
    args = parser.parse_args()
    package = json.loads(ASSET.read_text(encoding="utf-8"))
    files = build_outputs(package)
    if args.check:
        stale = [name for name, content in files.items() if not (OUTPUT / name).is_file() or (OUTPUT / name).read_text(encoding="utf-8") != content]
        if stale:
            raise SystemExit("Stale printable output: " + ", ".join(stale))
    else:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for name, content in files.items():
            (OUTPUT / name).write_text(content, encoding="utf-8")
    print(f"8 bilingual learner/review HTML files and exact-exposure manifest {'checked' if args.check else 'written'}.")


if __name__ == "__main__":
    main()
