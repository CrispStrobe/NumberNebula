"""Regression checks for assessment-safe, mathematically faithful paper output.

These tests inspect SVG geometry and generated content, not browser pagination.
The latter remains a visual check in the supported browser engines.
"""
from __future__ import annotations

import copy
import json
import math
import re
import unittest
import xml.etree.ElementTree as ET

from build_content import build_package
from build_print import (
    OUTPUT, REHEARSAL_IDS, answer_text, build_outputs, render_figure, render_task,
)
from common import L, figure
from validate_content import FIGURES

NS = {"s": "http://www.w3.org/2000/svg"}


def elements(svg, tag):
    return ET.fromstring(svg).findall(f".//s:{tag}", NS)


def labels(svg):
    return [node.text for node in elements(svg, "text")]


class PrintTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package = build_package()
        cls.tasks = {task["id"]: task for task in cls.package["tasks"]}
        cls.outputs = build_outputs(cls.package)
        cls.manifest = json.loads(cls.outputs["manifest.json"])

    def test_all_eight_booklets_and_manifest_are_reproducible(self):
        self.assertEqual(len(self.outputs), 9)
        self.assertEqual(sum(name.endswith(".html") for name in self.outputs), 8)
        for name, expected in self.outputs.items():
            with self.subTest(name=name):
                self.assertEqual((OUTPUT / name).read_text(encoding="utf-8"), expected)

    def test_manifest_matches_exact_visible_families_and_preserves_checks(self):
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(len(self.manifest["worksheets"]), 2)
        exposed = {}
        for worksheet in self.manifest["worksheets"]:
            mode = worksheet["mode"]
            task_ids = worksheet["taskIds"]
            self.assertEqual(len(task_ids), 64 if mode == "practice" else 20)
            self.assertEqual(len(task_ids), len(set(task_ids)))
            self.assertTrue(all(self.tasks[id]["use"] == mode for id in task_ids))
            exposed[mode] = {self.tasks[id]["familyId"] for id in task_ids}
            for category in ("files", "solutions"):
                self.assertEqual(set(worksheet[category]), {"de", "en"})
                for filename in worksheet[category].values():
                    visible = re.findall(r'data-task-id="([^"]+)"', self.outputs[filename])
                    self.assertEqual(visible, task_ids)
        self.assertTrue(exposed["practice"].isdisjoint(exposed["rehearsal"]))
        checked = {item["familyId"] for item in self.package["tasks"] if item["use"] == "check"}
        self.assertTrue(checked.isdisjoint(exposed["practice"] | exposed["rehearsal"]))
        self.assertEqual(
            next(w["taskIds"] for w in self.manifest["worksheets"] if w["mode"] == "rehearsal"),
            REHEARSAL_IDS,
        )

    def test_learner_output_never_embeds_solution_rules_or_feedback(self):
        item = copy.deepcopy(self.tasks["mz01_bundle_exchange"])
        item["hints"] = [L("HINT_SECRET_DE", "HINT_SECRET_EN")]
        item["solution"] = L("WORKED_SECRET_DE", "WORKED_SECRET_EN")
        item["parts"] = [
            {
                "id": "explanation", "kind": "text", "prompt": L("Begründe.", "Explain."),
                "maxPoints": 1, "competencyIds": ["M-Z01"],
                "answer": {"type": "manual", "criteria": L("CRITERIA_SECRET_DE", "CRITERIA_SECRET_EN")},
                "rubric": [L("RUBRIC_SECRET_DE", "RUBRIC_SECRET_EN")],
                "errors": [{"value": "unlikely", "code": "SECRET_ERROR_CODE",
                            "feedback": L("ERROR_SECRET_DE", "ERROR_SECRET_EN")}],
            },
            {
                "id": "calculation", "kind": "number", "prompt": L("Rechne.", "Calculate."),
                "maxPoints": 1, "competencyIds": ["M-Z01"],
                "answer": {"type": "number", "value": 987654},
            },
        ]
        for language in ("de", "en"):
            learner = render_task(item, 1, language, False)
            key = render_task(item, 1, language, True)
            for secret in ("HINT_SECRET", "WORKED_SECRET", "CRITERIA_SECRET", "RUBRIC_SECRET",
                           "SECRET_ERROR_CODE", "ERROR_SECRET", "987654"):
                self.assertNotIn(secret, learner)
            for visible in ("WORKED_SECRET", "CRITERIA_SECRET", "RUBRIC_SECRET", "987654"):
                self.assertIn(visible, key)

    def test_generated_documents_are_self_contained_and_escaped(self):
        for name, document in self.outputs.items():
            if not name.endswith(".html"):
                continue
            with self.subTest(name=name):
                self.assertNotRegex(document, r'<(?:img|script|link)\b[^>]*(?:src|href)\s*=')
                self.assertNotRegex(document, r'(?:fetch\s*\(|XMLHttpRequest|@import|url\s*\()')
                self.assertIn('onclick="window.print()"', document)
                self.assertIn('id="domain-filter"', document)
                self.assertIn("[hidden] { display: none !important; }", document)
                self.assertEqual(document.count("<script>"), 1)
                if "_solutions" not in name:
                    self.assertNotIn('class="solution"', document)
                    self.assertNotIn('class="rubric"', document)
        unsafe = figure("table", {"headers": ["<x>"], "rows": [['" & >']]},
                        "<Beschreibung>", "<Description>")
        rendered = render_figure(unsafe, "en")
        self.assertNotIn("<x>", rendered)
        self.assertIn("&lt;x&gt;", rendered)
        ET.fromstring(rendered)

    def test_every_authored_figure_renders_as_well_formed_svg_or_table(self):
        kinds = set()
        for item in self.package["tasks"]:
            figures = ([item["figure"]] if "figure" in item else [])
            figures += [part["figure"] for part in item["parts"] if "figure" in part]
            for fig in figures:
                kinds.add(fig["kind"])
                for language in ("de", "en"):
                    with self.subTest(item=item["id"], kind=fig["kind"], language=language):
                        tree = ET.fromstring(render_figure(fig, language))
                        if fig["kind"] == "table":
                            self.assertEqual(tree.tag, "table")
                        else:
                            self.assertEqual(tree.tag, f'{{{NS["s"]}}}svg')
                            self.assertEqual(tree.attrib["role"], "img")
                            self.assertTrue(tree.attrib["aria-label"])
                            _, _, width, height = map(float, tree.attrib["viewBox"].split())
                            self.assertGreater(width, 0)
                            self.assertGreater(height, 0)
        self.assertEqual(kinds, FIGURES)

    def test_comparison_squares_have_one_common_geometric_scale(self):
        fig = figure("shapeComparison", {"shapes": [
            {"id": "A", "cells": ["0,0", "0,1", "1,0", "1,1", "2,0"]},
            {"id": "B", "cells": ["0,0", "0,1", "0,2", "1,0", "1,1", "1,2"]},
        ]}, "Gleich große Einheitsquadrate.", "Equal unit squares.")
        squares = elements(render_figure(fig, "en"), "rect")
        self.assertEqual(len(squares), 11)
        self.assertEqual({(node.attrib["width"], node.attrib["height"]) for node in squares},
                         {("23", "23")})
        # B uses the same cell width despite occupying a wider bounding box.
        first_b, second_b = squares[5:7]
        self.assertEqual(float(second_b.attrib["x"]) - float(first_b.attrib["x"]), 23)

    def test_polygon_uniform_scale_preserves_lengths_and_right_angles(self):
        fig = figure("polygon", {"points": [[0, 0], [4, 0], [4, 3]]},
                     "Ein Dreieck.", "A triangle.")
        polygon = elements(render_figure(fig, "en"), "polygon")[0]
        points = [tuple(map(float, point.split(","))) for point in polygon.attrib["points"].split()]
        a, b, c = points
        horizontal = (b[0] - a[0], b[1] - a[1])
        vertical = (c[0] - b[0], c[1] - b[1])
        self.assertAlmostEqual(sum(x * y for x, y in zip(horizontal, vertical)), 0)
        self.assertAlmostEqual(math.hypot(*horizontal) / math.hypot(*vertical), 4 / 3, places=5)

    def test_cube_plan_keeps_all_givens_and_orientation_without_projection_answer(self):
        for item in self.package["tasks"]:
            fig = item.get("figure", {})
            if fig.get("kind") != "cubePlan":
                continue
            text = labels(render_figure(fig, "en"))
            data = fig["data"]
            self.assertEqual([int(value) for value in text if value.isdigit()],
                             [value for row in data["heights"] for value in row])
            self.assertEqual(text[0], "back")
            self.assertIn("front", text)
            self.assertEqual("right" in text, data["view"] == "right")
            # Only the top-view height grid is rendered; no derived silhouette.
            self.assertEqual(len(elements(render_figure(fig, "en"), "rect")),
                             sum(len(row) for row in data["heights"]))

    def test_number_line_marks_do_not_print_the_answer_as_a_label(self):
        fig = figure("numberLine", {"min": 200, "max": 300, "step": 10,
                                   "marks": [{"value": 260, "label": "A"}]},
                     "A liegt am sechsten Teilstrich nach 200.",
                     "A is at the sixth tick after 200.")
        rendered = render_figure(fig, "en")
        self.assertEqual(labels(rendered), ["200", "300", "A"])
        point = elements(rendered, "circle")[0]
        self.assertAlmostEqual(float(point.attrib["cx"]), 28 + 0.6 * 450)

    def test_clock_hour_hand_advances_with_minutes(self):
        fig = self.tasks["mg05_afternoon_clock"]["figure"]
        rendered = render_figure(fig, "en")
        self.assertNotIn("15:25", rendered)
        hands = elements(rendered, "line")
        self.assertEqual(len(hands), 2)
        minute, hour = hands
        minute_angle = math.atan2(float(minute.attrib["y2"]) - 90, float(minute.attrib["x2"]) - 90)
        hour_angle = math.atan2(float(hour.attrib["y2"]) - 90, float(hour.attrib["x2"]) - 90)
        self.assertAlmostEqual(math.degrees(minute_angle), 60, places=3)
        self.assertAlmostEqual(math.degrees(hour_angle), 12.5, places=3)

    def test_chart_uses_linear_zero_baseline_and_labelled_axis_steps(self):
        fig = figure("barChart", {"labels": ["A", "B"], "values": [10, 25],
                                 "max": 30, "step": 5, "yLabel": L("Anzahl", "Count")},
                     "Säulen und eine Skala in Fünferschritten.",
                     "Bars and an axis marked in steps of five.")
        rendered = render_figure(fig, "en")
        bars = elements(rendered, "rect")
        self.assertEqual([float(node.attrib["height"]) for node in bars], [50, 125])
        self.assertTrue(all(float(node.attrib["y"]) + float(node.attrib["height"]) == 176
                            for node in bars))
        self.assertEqual(labels(rendered)[:7], ["0", "5", "10", "15", "20", "25", "30"])
        self.assertEqual(labels(rendered)[7:], ["A", "B", "Count"])

    def test_cells_keys_add_only_new_cells_and_use_human_row_labels(self):
        item = self.tasks["mr05_vertical_tile_reflection"]
        part = next(part for part in item["parts"] if part["kind"] == "cells")
        given = part["figure"]["data"]["cells"]
        answers = part["answer"]["values"]
        self.assertTrue(set(given).isdisjoint(answers))
        learner = render_figure(part["figure"], "en", response=True)
        key = render_figure(part["figure"], "en", additions=answers, response=True)
        self.assertNotIn("+", labels(learner))
        self.assertEqual(labels(key).count("+"), len(answers))
        for cell in answers:
            row, col = map(int, cell.split(","))
            self.assertIn(f"row {row + 1}, column {col + 1}", answer_text(part, "en"))
        self.assertEqual(sum(node.attrib["fill"] == "#aebbc4" for node in elements(key, "rect")),
                         len(given))
        self.assertEqual(sum(node.attrib["fill"] == "#406b66" for node in elements(key, "rect")),
                         len(answers))

    def test_place_value_headers_are_localized(self):
        fig = self.tasks["mz01_bundle_exchange"]["figure"]
        self.assertEqual(labels(render_figure(fig, "de"))[::2], ["H", "Z", "E"])
        self.assertEqual(labels(render_figure(fig, "en"))[::2], ["H", "T", "O"])

    def test_paper_follow_through_guidance_matches_feasible_precision(self):
        money = self.tasks["mg04_reverse_receipt"]
        de = render_task(money, 1, "de", True)
        en = render_task(money, 1, "en", True)
        self.assertIn("− 4,5", de)
        self.assertIn("vollen Cent", de)
        self.assertIn("nichtnegativ", de)
        self.assertIn("whole cents", en)
        self.assertIn("nonnegative", en)
        count = self.tasks["mz04_inverse_wall"]
        guidance = render_task(count, 1, "en", True)
        self.assertIn("nonnegative whole numbers", guidance)

    def test_rehearsal_work_time_begins_after_general_instructions(self):
        en = self.outputs["rehearsal_en.html"]
        de = self.outputs["rehearsal_de.html"]
        self.assertIn("After reading the general instructions, begin 45 minutes of work", en)
        self.assertIn("Nach dem Lesen der allgemeinen Hinweise beginnen 45 Minuten Arbeitszeit", de)
        self.assertNotIn("40 minutes", en)
        self.assertIn("not an official test", en)
        self.assertIn("keine amtliche Niveaustufe", de)
        self.assertIn("Practice evidence is not a test prediction", en)


if __name__ == "__main__":
    unittest.main()
