"""Independent mathematics and adversarial contract checks for authored items."""
from __future__ import annotations

import copy
import itertools
import json
import math
import re
import unittest
from collections import Counter, deque
from decimal import Decimal
from fractions import Fraction

from build_content import ASSET, build_package, serialized
from validate_content import ContentError, SKILLS, canonical_shape, validate_package


def negate(vector):
    return tuple(-value for value in vector)


def fold_normals(cells):
    """Independently fold a grid net by propagating orthonormal 3D face bases.

    Reject overlaps, inconsistent cycles, disconnected pieces and wrong counts.
    No answer key or production rendering implementation is consulted.
    """
    points = {tuple(map(int, cell.split(","))) for cell in cells}
    if len(points) != 6:
        return None
    origin = min(points)
    bases = {origin: ((1, 0, 0), (0, 1, 0), (0, 0, 1))}
    queue = deque([origin])
    while queue:
        row, col = queue.popleft()
        u, v, n = bases[(row, col)]
        neighbours = [
            ((row, col + 1), (negate(n), v, u)),
            ((row, col - 1), (n, v, negate(u))),
            ((row + 1, col), (u, negate(n), v)),
            ((row - 1, col), (u, n, negate(v))),
        ]
        for point, basis in neighbours:
            if point not in points:
                continue
            if point in bases:
                if bases[point] != basis:
                    return None
            else:
                bases[point] = basis
                queue.append(point)
    if len(bases) != 6 or len({basis[2] for basis in bases.values()}) != 6:
        return None
    return {point: basis[2] for point, basis in bases.items()}


def clock_minutes(text):
    hours, minutes = map(int, text.split(":"))
    return hours * 60 + minutes


def event_category(outcomes, predicate):
    flags = [bool(predicate(outcome)) for outcome in outcomes]
    return "certain" if all(flags) else ("possible" if any(flags) else "impossible")


class CourseCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package = json.loads(ASSET.read_text(encoding="utf-8"))
        cls.tasks = {item["id"]: item for item in cls.package["tasks"]}

    def part(self, task_id, part_id):
        return next(part for part in self.tasks[task_id]["parts"] if part["id"] == part_id)

    def value(self, task_id, part_id):
        return self.part(task_id, part_id)["answer"]["value"]

    def values(self, task_id, part_id):
        return set(self.part(task_id, part_id)["answer"]["values"])

    def assertNumber(self, task_id, part_id, expected):
        self.assertAlmostEqual(float(self.value(task_id, part_id)), float(expected), places=8,
                               msg=f"{task_id}.{part_id}")


class ContractTests(CourseCase):
    def test_complete_bilingual_coverage_and_authored_asset_reproducibility(self):
        summary = validate_package(self.package)
        self.assertEqual(summary["tasks"], 128)
        self.assertEqual(summary["modes"], {"practice": 64, "check": 32, "rehearsal": 32})
        self.assertEqual(summary["domains"], {"numbers": 48, "geometry": 32, "measurement": 28, "data": 20})
        self.assertEqual(ASSET.read_text(encoding="utf-8"), serialized(build_package()))
        self.assertEqual({c["id"] for c in self.package["competencies"]}, SKILLS)

    def test_rejects_same_family_in_practice_and_check(self):
        bad = copy.deepcopy(self.package)
        practice = next(item for item in bad["tasks"] if item["use"] == "practice")
        check = next(item for item in bad["tasks"] if item["use"] == "check")
        check["familyId"] = practice["familyId"]
        with self.assertRaisesRegex(ContentError, "family crosses"):
            validate_package(bad)

    def test_rejects_answer_leak_in_student_figure(self):
        bad = copy.deepcopy(self.package)
        item = next(item for item in bad["tasks"] if "figure" in item)
        item["figure"]["data"]["solution"] = {"value": 123}
        with self.assertRaisesRegex(ContentError, "answer data"):
            validate_package(bad)

    def test_rejects_missing_option_and_invalid_cell(self):
        bad = copy.deepcopy(self.package)
        choice = next(part for item in bad["tasks"] for part in item["parts"] if part["kind"] == "choice")
        choice["answer"]["value"] = "not-an-offered-option"
        with self.assertRaisesRegex(ContentError, "correct option missing"):
            validate_package(bad)
        bad = copy.deepcopy(self.package)
        grid = next(part for item in bad["tasks"] for part in item["parts"] if part["kind"] == "cells")
        grid["answer"]["values"] = ["99,99"]
        with self.assertRaisesRegex(ContentError, "outside bounds"):
            validate_package(bad)

    def test_rejects_inconsistent_follow_through_and_wrong_language(self):
        bad = copy.deepcopy(self.package)
        part = next(part for item in bad["tasks"] for part in item["parts"] if "carryFrom" in part)
        part["carryOffset"] += 1
        with self.assertRaisesRegex(ContentError, "carry arithmetic"):
            validate_package(bad)
        bad = copy.deepcopy(self.package)
        del bad["tasks"][0]["hints"][0]["en"]
        with self.assertRaisesRegex(ContentError, "de/en"):
            validate_package(bad)

    def test_manual_parts_have_reviewable_point_criteria(self):
        manual_parts = [part for item in self.tasks.values() for part in item["parts"] if part["kind"] == "text"]
        self.assertGreater(len(manual_parts), 35)
        for part in manual_parts:
            self.assertEqual(part["answer"]["type"], "manual")
            self.assertTrue(part["rubric"])
            if part["maxPoints"] > 1:
                self.assertEqual(len(part["rubric"]), part["maxPoints"])


class NumberSemanticsTests(CourseCase):
    def test_conventional_arithmetic_recomputed_from_displayed_expressions(self):
        checked = 0
        for item in self.tasks.values():
            for part in item["parts"]:
                match = re.fullmatch(r"(\d+) ([+−·:]) (\d+) = \?", part["prompt"]["de"])
                if not match or part["kind"] != "number":
                    continue
                left, op, right = match.groups()
                left, right = int(left), int(right)
                computed = {"+": lambda: left + right, "−": lambda: left - right,
                            "·": lambda: left * right, ":": lambda: left / right}[op]()
                self.assertNumber(item["id"], part["id"], computed)
                checked += 1
        self.assertGreaterEqual(checked, 6)

    def test_noncanonical_place_value_and_missing_hundreds(self):
        task = self.tasks["mz01_bundle_exchange"]
        quantities = [column["value"] for column in task["figure"]["data"]["columns"]]
        value = sum(count * place for count, place in zip(quantities, [100, 10, 1]))
        self.assertNumber(task["id"], "value", value)
        self.assertNumber(task["id"], "tens", value // 10 % 10)
        task = self.tasks["mz01_missing_bundle_count"]
        total, thousands, tens, ones = map(int, re.findall(r"\d+", task["prompt"]["en"]))
        missing = (total - thousands * 1000 - tens * 10 - ones) / 100
        self.assertNumber(task["id"], "hundreds", missing)

    def test_digit_cards_and_interval_constraints(self):
        task = self.tasks["mz01_digit_card_minimum"]
        digits = [int(n) for n in re.search(r"cards ([\d, ]+) and (\d)", task["prompt"]["en"]).group(0).replace("cards ", "").replace(" and ", ", ").split(", ")]
        candidates = [int("".join(map(str, values))) for values in itertools.permutations(digits) if values[0] != 0]
        correct = "".join(self.part(task["id"], "cards")["answer"]["values"])
        self.assertEqual(int(correct), min(candidates))
        self.assertEqual(self.values("mz02_missing_comparison_digit", "digits"),
                         {str(d) for d in range(10) if 654 < 600 + 10 * d + 4 < 684})

    def test_number_line_midpoint_and_reverse_endpoint(self):
        task = self.tasks["mz03_marked_number_line"]
        mark = task["figure"]["data"]["marks"][0]
        target = int(re.findall(r"\d+", self.part(task["id"], "distance")["prompt"]["en"])[0])
        self.assertNumber(task["id"], "a", mark["value"])
        self.assertNumber(task["id"], "distance", abs(target - mark["value"]))
        task = self.tasks["mz03_midpoint_balance"]
        left, right = map(int, re.findall(r"\d+", task["prompt"]["en"]))
        self.assertNumber(task["id"], "middle", (left + right) / 2)
        task = self.tasks["mz03_missing_endpoint"]
        middle, right = map(int, re.findall(r"\d+", task["prompt"]["en"]))
        self.assertNumber(task["id"], "left", 2 * middle - right)
        self.assertNumber(task["id"], "gap", right - middle)

    def test_inverse_wall_from_given_bricks_and_carry_dependency(self):
        task = self.tasks["mz04_inverse_wall"]
        rows = task["figure"]["data"]["rows"]
        middle = rows[2][0] - rows[1][0]
        bottom = middle - rows[0][1]
        self.assertNumber(task["id"], "middle", middle)
        self.assertNumber(task["id"], "bottom", bottom)
        self.assertEqual(rows[0][0] + rows[0][1], rows[1][0])
        self.assertEqual(self.part(task["id"], "bottom")["carryOffset"], -rows[0][1])

    def test_strategy_corrections_are_directionally_correct(self):
        self.assertNumber("mz07_paired_compensation", "sum", 398 + 47)
        original = 804 - 299
        options = self.part("mz07_subtraction_compensation", "adjust")["options"]
        computed = {}
        for option in options:
            a, op, b = re.fullmatch(r"(\d+) ([+−]) (\d+)", option["label"]["de"]).groups()
            computed[option["id"]] = int(a) + int(b) if op == "+" else int(a) - int(b)
        self.assertEqual([key for key, value in computed.items() if value == original],
                         [self.value("mz07_subtraction_compensation", "adjust")])
        self.assertEqual(12 * 19, 12 * 20 - 12)
        self.assertEqual(self.value("mz07_multiply_near_twenty", "adjust"), "a")
        self.assertNumber("mz07_near_thousand_correction", "correct", 999 + 68)

    def test_alternating_machine_and_table_rule(self):
        values = [6]
        for step in range(6):
            values.append(values[-1] + 5 if step % 2 == 0 else values[-1] * 2)
        self.assertNumber("mz08_alternating_machine", "next", values[-2])
        self.assertNumber("mz08_alternating_machine", "after", values[-1])
        rows = self.tasks["mz08_input_output_rule"]["figure"]["data"]["rows"]
        inputs = [(int(x), int(y)) for x, y in rows]
        slope = Fraction(inputs[1][1] - inputs[0][1], inputs[1][0] - inputs[0][0])
        intercept = inputs[0][1] - slope * inputs[0][0]
        self.assertTrue(all(y == slope * x + intercept for x, y in inputs))
        self.assertNumber("mz08_input_output_rule", "output", slope * 6 + intercept)

    def test_wall_and_digit_optimisation_by_exhaustive_search(self):
        task = self.tasks["mz09_maximise_wall_top"]
        match = re.search(r"Put (\d+), (\d+) and (\d+)", task["prompt"]["en"])
        digits = list(map(int, match.groups()))
        evaluated = [(a + 2 * b + c, b) for a, b, c in itertools.permutations(digits)]
        optimum = max(value for value, _ in evaluated)
        self.assertNumber(task["id"], "top", optimum)
        self.assertEqual({middle for value, middle in evaluated if value == optimum},
                         {self.value(task["id"], "middle")})
        task = self.tasks["mz09_largest_two_digit_difference"]
        digits = [2, 4, 7, 9]
        self.assertIn("2, 4, 7 and 9", task["prompt"]["en"])
        candidates = [(10 * a + b - 10 * c - d, 10 * a + b, 10 * c + d)
                      for a, b, c, d in itertools.permutations(digits)]
        best, larger, smaller = max(candidates)
        self.assertNumber(task["id"], "difference", best)
        self.assertNumber(task["id"], "larger", larger)
        self.assertNumber(task["id"], "smaller", smaller)

    def test_constrained_pair_optimisation_and_whole_packs(self):
        task = self.tasks["mz09_best_pair_below_limit"]
        values = list(map(int, re.findall(r"\d+", task["prompt"]["en"])))
        cards, limit = values[:4], values[4]
        allowed = [sum(pair) for pair in itertools.combinations(cards, 2) if sum(pair) <= limit]
        self.assertNumber(task["id"], "best", max(allowed))
        options = self.part(task["id"], "pairs")["options"]
        best_ids = {option["id"] for option in options if sum(map(int, re.findall(r"\d+", option["label"]["en"]))) == max(allowed)}
        self.assertEqual(self.values(task["id"], "pairs"), best_ids)
        task = self.tasks["mz10_whole_pack_purchase"]
        needed, available, pack = map(int, re.findall(r"\d+", task["prompt"]["en"]))
        self.assertNumber(task["id"], "missing", needed - available)
        self.assertNumber(task["id"], "packs", math.ceil((needed - available) / pack))

    def test_combinations_with_repetition_and_leading_zero_rules(self):
        codes = {"".join(chars) for chars in itertools.product("AB", repeat=2)}
        self.assertEqual(self.values("mz12_two_symbol_codes", "codes"), codes)
        task = self.tasks["mz12_even_digit_pairs"]
        self.assertIn("0, 2, 5 and 7", task["prompt"]["en"])
        numbers = {str(10 * a + b) for a, b in itertools.permutations([0, 2, 5, 7], 2) if a != 0 and b % 2 == 0}
        self.assertEqual(self.values(task["id"], "numbers"), numbers)
        self.assertNumber(task["id"], "count", len(numbers))
        pairs = list(itertools.combinations(["Alex", "Bo", "Cem", "Dani"], 2))
        self.assertNumber("mz12_one_game_per_pair", "games", len(pairs))


class GeometrySemanticsTests(CourseCase):
    def test_polygon_lengths_angles_and_scalene_counterexample(self):
        task = self.tasks["mr01_tilted_square"]
        points = task["figure"]["data"]["points"]
        edges = [(points[(i + 1) % 4][0] - points[i][0], points[(i + 1) % 4][1] - points[i][1]) for i in range(4)]
        self.assertEqual(len({dx * dx + dy * dy for dx, dy in edges}), 1)
        self.assertTrue(all(edges[i][0] * edges[(i + 1) % 4][0] + edges[i][1] * edges[(i + 1) % 4][1] == 0 for i in range(4)))
        triangle = self.tasks["mr05_triangle_axis_counterexample"]["figure"]["data"]["points"]
        lengths = {math.dist(triangle[i], triangle[(i + 1) % 3]) for i in range(3)}
        self.assertEqual(lengths, {3, 4, 5})
        self.assertNumber("mr05_triangle_axis_counterexample", "axes", 0)

    def test_area_tiles_factor_pairs_and_partition(self):
        factors = {(a, 12 // a) for a in range(1, 13) if 12 % a == 0 and a <= 12 // a}
        expected = {f"{a}x{b}" for a, b in factors}
        self.assertEqual(self.values("mr02_tile_rectangle_factors", "dimensions"), expected)
        self.assertNumber("mr02_tile_rectangle_factors", "count", len(factors))
        task = self.tasks["mr02_complete_tile_rectangle"]
        part = self.part(task["id"], "fill")
        data = part["figure"]["data"]
        whole = {f"{r},{c}" for r in range(data["rows"]) for c in range(data["cols"])}
        self.assertEqual(self.values(task["id"], "fill"), whole - set(data["filled"]))
        self.assertNumber(task["id"], "total", len(whole))
        data = self.tasks["mr02_equal_vertical_partition"]["figure"]["data"]
        self.assertNumber("mr02_equal_vertical_partition", "columns", data["cols"] // 2)
        self.assertNumber("mr02_equal_vertical_partition", "tiles", data["rows"] * data["cols"] // 2)

    def test_area_comparison_counts_given_units(self):
        shapes = self.tasks["mr03_same_unit_area_comparison"]["figure"]["data"]["shapes"]
        areas = {shape["id"]: len(set(shape["cells"])) for shape in shapes}
        self.assertNumber("mr03_same_unit_area_comparison", "area_a", areas["A"])
        self.assertEqual(self.value("mr03_same_unit_area_comparison", "larger").upper(), max(areas, key=areas.get))
        self.assertNumber("mr03_different_area_units", "area_a", 6 * 2 * 2)
        self.assertNumber("mr03_combine_half_squares", "area", 4 + Fraction(1, 2) + Fraction(1, 2))

    def test_clockwise_cell_rotation_and_nonrotatable_mirror(self):
        task = self.tasks["mr04_quarter_turn_grid"]
        data = task["figure"]["data"]
        rotated = {f"{c},{data['rows'] - 1 - r}" for r, c in map(lambda v: tuple(map(int, v.split(","))), data["filled"])}
        self.assertEqual(self.values(task["id"], "rotated"), rotated)
        shapes = self.tasks["mr04_rotation_or_reflection"]["figure"]["data"]["shapes"]
        a = {tuple(map(int, cell.split(","))) for cell in shapes[0]["cells"]}
        b = {tuple(map(int, cell.split(","))) for cell in shapes[1]["cells"]}
        normalise = lambda points: frozenset((r - min(x for x, _ in points), c - min(y for _, y in points)) for r, c in points)
        rotations = set()
        for _ in range(4):
            rotations.add(normalise(a))
            a = {(c, -r) for r, c in a}
        self.assertNotIn(normalise(b), rotations)
        self.assertEqual(self.value("mr04_rotation_or_reflection", "possible"), "no")

    def test_reflection_and_two_fold_symmetries(self):
        part = self.part("mr05_vertical_tile_reflection", "reflection")
        data = part["figure"]["data"]
        axis = data["axis"]["at"]
        mirrored = {f"{r},{2 * axis - 1 - c}" for r, c in map(lambda v: tuple(map(int, v.split(","))), data["cells"])}
        self.assertEqual(self.values("mr05_vertical_tile_reflection", "reflection"), mirrored)
        part = self.part("mr05_two_fold_holes", "other_holes")
        data = part["figure"]["data"]
        row, col = map(int, data["filled"][0].split(","))
        holes = {f"{r},{c}" for r in [row, data["rows"] - 1 - row] for c in [col, data["cols"] - 1 - col]}
        self.assertEqual(self.values("mr05_two_fold_holes", "other_holes"), holes - set(data["filled"]))
        self.assertNumber("mr05_two_fold_holes", "total_holes", len(holes))

    def test_cube_counts_projections_and_inverse_constraints(self):
        heights = self.tasks["mr06_front_view_heights"]["figure"]["data"]["heights"]
        projection = [max(column) for column in zip(*heights)]
        self.assertNumber("mr06_front_view_heights", "left", projection[0])
        self.assertNumber("mr06_front_view_heights", "right", projection[1])
        heights = self.tasks["mr06_total_versus_side_view"]["figure"]["data"]["heights"]
        self.assertNumber("mr06_total_versus_side_view", "total", sum(map(sum, heights)))
        self.assertNumber("mr06_total_versus_side_view", "view", max(heights[0]))
        heights = self.tasks["mr06_right_view_two_rows"]["figure"]["data"]["heights"]
        self.assertNumber("mr06_right_view_two_rows", "back", max(heights[0]))
        self.assertNumber("mr06_right_view_two_rows", "front", max(heights[1]))
        possible = set()
        for option in self.part("mr06_reverse_view_plans", "plans")["options"]:
            a, b, c, d = map(int, re.findall(r"\d+", option["label"]["en"]))
            if a + b + c + d == 6 and [max(a, c), max(b, d)] == [2, 3]:
                possible.add(option["id"])
        self.assertEqual(self.values("mr06_reverse_view_plans", "plans"), possible)

    def test_net_opposites_by_independent_three_dimensional_folding(self):
        for task_id, face_part in [("mr07_cross_net_opposites", {"C": "opposite_c", "B": "opposite_b"}),
                                   ("mr07_offset_net_opposites", {"E": "opposite_e", "B": "opposite_b"})]:
            data = self.tasks[task_id]["figure"]["data"]
            folded = fold_normals(data["cells"])
            self.assertIsNotNone(folded)
            normals = {label: folded[tuple(map(int, cell.split(",")))] for cell, label in data["labels"].items()}
            for face, part_id in face_part.items():
                opposite = next(label for label, normal in normals.items() if normal == negate(normals[face]))
                self.assertEqual(self.value(task_id, part_id), opposite)

    def test_net_completion_is_unique_within_input_bounds(self):
        data = self.part("mr07_complete_cross_net", "extra")["figure"]["data"]
        possible = []
        for row in range(data["rows"]):
            for col in range(data["cols"]):
                cell = f"{row},{col}"
                if cell not in data["cells"] and fold_normals(data["cells"] + [cell]) is not None:
                    possible.append(cell)
        self.assertEqual(set(possible), self.values("mr07_complete_cross_net", "extra"))
        self.assertEqual(len(possible), 1)

    def test_rehearsal_nets_are_valid_or_invalid_as_marked_and_unseen(self):
        shapes = self.tasks["mr07_valid_net_selection"]["figure"]["data"]["shapes"]
        valid = {shape["id"] for shape in shapes if fold_normals(shape["cells"]) is not None}
        self.assertEqual(self.values("mr07_valid_net_selection", "valid"), valid)
        known = {canonical_shape(self.tasks[id]["figure"]["data"]["cells"])
                 for id in ["mr07_cross_net_opposites", "mr07_offset_net_opposites"]}
        new = {canonical_shape(shape["cells"]) for shape in shapes if shape["id"] in valid}
        self.assertTrue(known.isdisjoint(new), "A rehearsed cube net must not be presented as unseen.")
        self.assertIsNone(fold_normals([f"0,{i}" for i in range(6)]))
        self.assertIsNone(fold_normals([f"{r},{c}" for r in range(2) for c in range(3)]))

    def test_perimeter_area_and_unknown_side_recompute(self):
        task = self.tasks["mr08_area_and_boundary"]
        points = task["figure"]["data"]["points"]
        perimeter = sum(math.dist(points[i], points[(i + 1) % 4]) for i in range(4))
        area = abs(sum(points[i][0] * points[(i + 1) % 4][1] - points[(i + 1) % 4][0] * points[i][1] for i in range(4))) / 2
        self.assertNumber(task["id"], "perimeter", perimeter)
        self.assertNumber(task["id"], "area", area)
        task = self.tasks["mr08_missing_rectangle_side"]
        perimeter, long_side = map(int, re.findall(r"\d+", task["prompt"]["en"]))
        short = (perimeter - 2 * long_side) / 2
        self.assertNumber(task["id"], "short", short)
        self.assertNumber(task["id"], "area", short * long_side)
        self.assertNumber("mr08_one_row_extension", "area_change", 7 * 5 - 7 * 4)
        self.assertNumber("mr08_one_row_extension", "perimeter_change", 2 * (7 + 5) - 2 * (7 + 4))


class MeasurementSemanticsTests(CourseCase):
    def test_length_conversions_cutting_and_inverse_route(self):
        self.assertNumber("mg02_metres_centimetres", "all_cm", 100 + 35)
        metres, remainder = divmod(270, 100)
        self.assertNumber("mg02_metres_centimetres", "metres", metres)
        self.assertNumber("mg02_metres_centimetres", "remainder", remainder)
        self.assertNumber("mg02_compare_mixed_lengths", "difference", 218 - (2 * 100 + 8))
        self.assertNumber("mg02_cut_three_lengths", "left", 5 * 100 - 3 * 125)
        self.assertNumber("mg02_reconstruct_route_leg", "missing", 3 * 1000 - (1000 + 200) - 650)

    def test_constant_price_table_and_reverse_budget(self):
        rows = self.tasks["mg03_constant_rate_table"]["figure"]["data"]["rows"]
        rates_a = {Fraction(int(price_a.split()[0]), int(count)) for count, price_a, _ in rows}
        rates_b = {Fraction(int(price_b.split()[0]), int(count)) for count, _, price_b in rows}
        self.assertEqual(len(rates_a), 1)
        self.assertGreater(len(rates_b), 1)
        self.assertEqual(self.value("mg03_constant_rate_table", "stall"), "a")
        self.assertNumber("mg03_constant_rate_table", "eight", rates_a.pop() * 8)
        self.assertNumber("mg03_reverse_budget_quantity", "quantity", Fraction(9, 1) / Fraction(15, 10))
        self.assertIn("every other quantity", self.tasks["mg03_constant_rate_table"]["prompt"]["en"])

    def test_money_uses_exact_cents_and_budget_maximum(self):
        cost = 2 * Decimal("1.80") + 3 * Decimal("0.60")
        self.assertNumber("mg04_purchase_and_change", "cost", cost)
        self.assertNumber("mg04_purchase_and_change", "change", Decimal("10") - cost)
        task = self.tasks["mg04_price_table_budget"]
        prices = {row[0]["en"]: Decimal(row[1]["en"].lstrip("€")) for row in task["figure"]["data"]["rows"]}
        budget = Decimal(re.search(r"€(\d+)", task["prompt"]["en"]).group(1))
        remaining = budget - 2 * prices["Cereal bar"]
        bottles = int(remaining // prices["Water"])
        self.assertNumber(task["id"], "waters", bottles)
        self.assertNumber(task["id"], "returned", remaining - bottles * prices["Water"])
        self.assertGreater((bottles + 1) * prices["Water"], remaining)
        self.assertNumber("mg04_reverse_receipt", "spent", Decimal("20") - Decimal("7.50"))
        self.assertNumber("mg04_reverse_receipt", "game", Decimal("20") - Decimal("7.50") - Decimal("4.50"))

    def test_elapsed_time_backwards_planning_and_timetable(self):
        task = self.tasks["mg05_elapsed_with_break"]
        start, end = re.findall(r"\d{2}:\d{2}", task["prompt"]["en"])
        duration = clock_minutes(end) - clock_minutes(start)
        pause = int(re.search(r"(\d+)-minute break", task["prompt"]["en"]).group(1))
        self.assertNumber(task["id"], "duration", duration)
        self.assertNumber(task["id"], "working", duration - pause)
        self.assertNumber("mg05_backward_departure", "lead", 18 + 7)
        selected = self.value("mg05_backward_departure", "leave")
        selected_time = next(o["label"]["en"] for o in self.part("mg05_backward_departure", "leave")["options"] if o["id"] == selected)
        self.assertEqual(clock_minutes(selected_time), clock_minutes("17:05") - 18 - 7)
        task = self.tasks["mg05_timetable_with_walk"]
        appointment = clock_minutes(re.search(r"\d{2}:\d{2}", task["prompt"]["en"]).group())
        walk = int(re.search(r"(\d+)-minute walk", task["prompt"]["en"]).group(1))
        rows = task["figure"]["data"]["rows"]
        suitable = [(clock_minutes(departure), id, clock_minutes(arrival)) for id, departure, arrival in rows if clock_minutes(arrival) + walk <= appointment]
        _, id, arrival = max(suitable)
        self.assertEqual(self.value(task["id"], "bus").upper(), id)
        self.assertNumber(task["id"], "spare", appointment - arrival - walk)

    def test_clock_hand_time_and_nonzero_ruler(self):
        data = self.tasks["mg05_afternoon_clock"]["figure"]["data"]
        self.assertNumber("mg05_afternoon_clock", "hour", data["hour"])
        self.assertNumber("mg05_afternoon_clock", "minute", data["minute"])
        data = self.tasks["mg06_ruler_nonzero_start"]["figure"]["data"]
        self.assertNumber("mg06_ruler_nonzero_start", "length", data["end"] - data["start"])
        self.assertNumber("mg06_broken_ruler", "millimetres", (Decimal("7.5") - 3) * 10)
        self.assertNumber("mg06_paper_segment", "millimetres", Decimal("6.5") * 10)
        self.assertNumber("mg06_repair_drawn_length", "actual", 6 - 1)
        self.assertNumber("mg06_repair_drawn_length", "new_end", 1 + 6)

    def test_capacity_conversion_and_whole_cup_remainder(self):
        self.assertNumber("mg07_fill_to_one_litre", "add", 1000 - 750)
        self.assertNumber("mg07_fill_to_one_litre", "two_litres", 2 * 1000)
        self.assertNumber("mg07_three_cups", "poured", 3 * 200)
        self.assertNumber("mg07_three_cups", "left", 1000 - 3 * 200)
        self.assertNumber("mg07_compare_mixed_capacities", "difference", 1400 - (1000 + 250))
        cups, remainder = divmod(2 * 1000, 300)
        self.assertNumber("mg07_full_cups_remainder", "cups", cups)
        self.assertNumber("mg07_full_cups_remainder", "remaining", remainder)


class DataSemanticsTests(CourseCase):
    def test_table_rows_columns_and_two_constraints(self):
        rows = self.tasks["md01_two_way_table"]["figure"]["data"]["rows"]
        self.assertNumber("md01_two_way_table", "saturday", sum(int(row[2]) for row in rows))
        self.assertNumber("md01_two_way_table", "chess", sum(int(n) for n in rows[0][1:]))
        rows = self.tasks["md01_table_constraints"]["figure"]["data"]["rows"]
        suitable = [(id, int(seats)) for id, seats, price in rows if int(seats) >= 18 and int(price.split()[0]) <= 25]
        self.assertEqual(len(suitable), 1)
        self.assertEqual(self.value("md01_table_constraints", "room").upper(), suitable[0][0])
        self.assertNumber("md01_table_constraints", "spare", suitable[0][1] - 18)

    def test_constructed_bars_start_at_zero_and_have_correct_heights(self):
        task = self.tasks["md02_build_unit_bars"]
        given = {name: int(value) for name, value in re.findall(r"([ABC]) = (\d+)", task["prompt"]["en"])}
        data = self.part(task["id"], "bars")["figure"]["data"]
        expected = {f"{row},{col}" for col, name in enumerate("ABC") for row in range(data["rows"] - given[name], data["rows"])}
        self.assertEqual(self.values(task["id"], "bars"), expected)
        self.assertNumber("md02_choose_efficient_scale", "intervals", 20 / 5)
        valid_steps = [step for step in [1, 5, 10] if 6 * step >= max([18, 24, 30])]
        self.assertEqual(min(valid_steps), 5)
        self.assertEqual(self.value("md02_choose_efficient_scale", "step"), "five")

    def test_bad_bar_and_scaled_chart_values_recomputed(self):
        task = self.tasks["md02_repair_inaccurate_bar"]
        verified = {name: int(value) for name, value in re.findall(r"([ABC]) = (\d+)", task["prompt"]["en"])}
        chart = dict(zip(task["figure"]["data"]["labels"], task["figure"]["data"]["values"]))
        wrong = [name for name in chart if chart[name] != verified[name]]
        self.assertEqual(wrong, [self.value(task["id"], "wrong")])
        self.assertNumber(task["id"], "height", verified[wrong[0]])
        task = self.tasks["md03_read_two_step_chart"]
        chart = dict(zip(task["figure"]["data"]["labels"], task["figure"]["data"]["values"]))
        self.assertNumber(task["id"], "c", chart["C"])
        self.assertNumber(task["id"], "difference", chart["B"] - chart["A"])
        rows = self.tasks["md03_pictogram_key"]["figure"]["data"]["rows"]
        quantities = [row[1].count("●") * 4 for row in rows]
        self.assertNumber("md03_pictogram_key", "tuesday", quantities[1])
        self.assertNumber("md03_pictogram_key", "more", quantities[1] - quantities[0])

    def test_missing_category_and_false_double_claim(self):
        task = self.tasks["md03_unshown_category_total"]
        total = int(re.search(r"\d+", task["prompt"]["en"]).group())
        shown = sum(task["figure"]["data"]["values"])
        self.assertNumber(task["id"], "shown", shown)
        self.assertNumber(task["id"], "c", total - shown)
        task = self.tasks["md03_chart_double_claim"]
        chart = dict(zip(task["figure"]["data"]["labels"], task["figure"]["data"]["values"]))
        self.assertNotEqual(2 * chart["A"], chart["C"])
        self.assertEqual(self.value(task["id"], "true"), "no")

    def test_single_draw_and_die_event_categories(self):
        task = self.tasks["md04_bag_event_language"]
        population = [item["label"]["en"] for item in task["figure"]["data"]["tokens"] for _ in range(item["count"])]
        for part_id, predicate in [("red", lambda x: x == "red"), ("green", lambda x: x == "green"), ("red_or_blue", lambda x: x in {"red", "blue"})]:
            self.assertEqual(self.value(task["id"], part_id), event_category(population, predicate))
        die = list(range(1, 7))
        for part_id, predicate in [("odd", lambda x: x % 2 == 1), ("at_most_six", lambda x: x <= 6), ("seven", lambda x: x == 7)]:
            self.assertEqual(self.value("md04_die_event_categories", part_id), event_category(die, predicate))

    def test_independent_repeat_and_without_replacement(self):
        sectors = self.tasks["md04_repeat_spin_possible"]["figure"]["data"]["sectors"]
        labels = [sector["label"] for sector in sectors]
        outcomes = list(itertools.product(labels, repeat=2))
        self.assertEqual(self.value("md04_repeat_spin_possible", "aa"), event_category(outcomes, lambda x: x == ("A", "A")))
        self.assertFalse(all(second == "B" for first, second in outcomes if first == "A"))
        self.assertEqual(self.value("md04_repeat_spin_possible", "must_change"), "no")
        bag = self.tasks["md04_draw_two_without_replacement"]["figure"]["data"]["tokens"]
        population = [item["label"]["en"] for item in bag for _ in range(item["count"])]
        outcomes = list(itertools.combinations(population, 2))
        self.assertTrue(all("red" in outcome for outcome in outcomes))
        self.assertEqual(self.value("md04_draw_two_without_replacement", "certain"), "at_least_red")
        self.assertEqual(self.value("md04_draw_two_without_replacement", "two_blue"), event_category(outcomes, lambda x: x == ("blue", "blue")))

    def test_fair_additions_different_totals_and_rule_counts(self):
        bag = self.tasks["md05_make_fair_by_adding"]["figure"]["data"]["tokens"]
        counts = {item["label"]["en"]: item["count"] for item in bag}
        extra = counts["star"] - counts["circle"]
        self.assertNumber("md05_make_fair_by_adding", "add", extra)
        self.assertNumber("md05_make_fair_by_adding", "total", sum(counts.values()) + extra)
        task = self.tasks["md05_different_totals_same_share"]
        spinners = [task["figure"], self.part(task["id"], "compare")["figure"]]
        fractions = []
        for spinner in spinners:
            sectors = spinner["data"]["sectors"]
            fractions.append(Fraction(sum(x["weight"] for x in sectors if x["label"]["en"] == "S"), sum(x["weight"] for x in sectors)))
        self.assertEqual(fractions, [Fraction(1, 2), Fraction(1, 2)])
        self.assertEqual(self.value(task["id"], "compare"), "same")
        cards = range(1, 9)
        reference = {x for x in cards if x > 6}
        rules = {"even": {x for x in cards if x % 2 == 0}, "at_most_two": {x for x in cards if x <= 2}, "odd": {x for x in cards if x % 2}}
        equal = [key for key, outcomes in rules.items() if len(outcomes) == len(reference)]
        self.assertEqual(equal, [self.value("md05_fair_number_card_rules", "rule")])


if __name__ == "__main__":
    unittest.main()
