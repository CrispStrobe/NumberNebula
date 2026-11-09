"""Independent mathematics checks for every part of the transfer extension.

Givens are read from the visible figures/prompts. Paths and tower constraints
are enumerated; boundary/overlap counts use sets; money uses Decimal. Manual
explanations are checked for the required reasoning and remain manual evidence.
"""
from __future__ import annotations

import copy
import itertools
import re
import unittest
from collections import Counter
from decimal import Decimal
from fractions import Fraction

from build_content import build_package
from build_print import render_task
from content_extension import tasks
from validate_content import ContentError, validate_package


class ExtensionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.new_tasks = tasks()
        cls.items = {item["id"]: item for item in cls.new_tasks}

    def item(self, short_id):
        skill, slug = short_id.split("_", 1)
        return self.items[f"{skill}_zz_{slug}"]

    def parts(self, item):
        return {part["id"]: part for part in item["parts"]}

    def numeric(self, part, expected):
        self.assertEqual(part["answer"]["type"], "number")
        self.assertAlmostEqual(float(part["answer"]["value"]), float(expected), places=9)

    def chosen(self, part, expected):
        self.assertEqual(part["answer"], {"type": "choice", "value": expected})
        self.assertIn(expected, {option["id"] for option in part["options"]})

    def selected(self, part, expected):
        self.assertEqual(part["answer"]["type"], "set")
        self.assertEqual(set(part["answer"]["values"]), set(expected))

    def manual(self, part, required_phrases):
        self.assertEqual(part["kind"], "text")
        self.assertEqual(part["answer"]["type"], "manual")
        self.assertNotIn("value", part["answer"])
        self.assertEqual(part["maxPoints"], len(part["rubric"]))
        criterion = part["answer"]["criteria"]["en"].lower()
        for phrase in required_phrases:
            self.assertIn(phrase, criterion)

    def test_contract_partition_counts_and_later_ids(self):
        self.assertEqual(len(self.items), 16)
        self.assertEqual(sum(len(item["parts"]) for item in self.new_tasks), 41)
        self.assertEqual(Counter(item["use"] for item in self.new_tasks),
                         {"practice": 8, "check": 4, "rehearsal": 4})
        self.assertEqual(Counter(item["domain"] for item in self.new_tasks),
                         {"numbers": 4, "geometry": 4, "measurement": 4, "data": 4})
        package = build_package()
        package["tasks"] = copy.deepcopy(self.new_tasks)
        self.assertEqual(validate_package(package, complete=False)["parts"], 41)
        for item in self.new_tasks:
            self.assertRegex(item["id"], r"^m[zrgd]\d{2}_zz_[a-z0-9_]+$")
            self.assertGreaterEqual(item["level"], 2)
            self.assertEqual(item["source"]["kind"], "original")
            self.assertEqual(item["source"]["license"], "AGPL-3.0-only")

    def test_practice_variant_keeps_its_existing_family(self):
        tiling = self.item("mr02_square_and_corner_piece")
        self.assertEqual(tiling["familyId"], "mr02_complete_tile_rectangle")
        self.assertEqual(tiling["use"], "practice")
        practice_families = {item["familyId"] for item in self.new_tasks if item["use"] == "practice"}
        check_families = {item["familyId"] for item in self.new_tasks if item["use"] == "check"}
        rehearsal_families = {item["familyId"] for item in self.new_tasks if item["use"] == "rehearsal"}
        self.assertTrue(practice_families.isdisjoint(check_families | rehearsal_families))
        self.assertTrue(check_families.isdisjoint(rehearsal_families))
        package = build_package()
        package["tasks"] = copy.deepcopy(self.new_tasks)
        next(item for item in package["tasks"] if item["use"] == "check")["familyId"] = tiling["familyId"]
        with self.assertRaisesRegex(ContentError, "family crosses"):
            validate_package(package, complete=False)

    def test_division_doubling_uses_the_unchanged_group_size(self):
        item = self.item("mz07_division_doubling")
        before, size, known, after = map(int, re.findall(r"\d+", item["prompt"]["en"]))
        self.assertEqual(before // size, known)
        self.assertEqual(before % size, 0)
        self.assertEqual(after, 2 * before)
        self.assertEqual(after // size, 2 * known)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"groups", "reason"})
        self.numeric(parts["groups"], after // size)
        self.chosen(parts["reason"], "double_groups")
        self.assertNotEqual(after // (2 * size), after // size)
        self.assertNotEqual(known + size, after // size)

    def test_two_direction_grid_is_consistent_from_every_known_cell(self):
        item = self.item("mz08_two_direction_number_grid")
        rows = item["figure"]["data"]["rows"]
        start = int(rows[0][0])
        right = int(rows[0][1]) - start
        down = int(rows[1][0]) - start
        hidden = {}
        for row, values in enumerate(rows):
            for column, cell in enumerate(values):
                expected = start + row * down + column * right
                if cell.isdigit():
                    self.assertEqual(int(cell), expected)
                else:
                    hidden[cell.lower()] = expected
        parts = self.parts(item)
        self.assertEqual(set(parts), {"a", "b", "rule"})
        for part_id, expected in hidden.items():
            self.numeric(parts[part_id], expected)
        self.chosen(parts["rule"], f"right{right}_down{down}")

    def test_grid_routes_enumerate_complete_paths_and_blocked_intermediate_cells(self):
        item = self.item("mz12_constrained_grid_routes")
        grid = item["figure"]["data"]
        blocked = {tuple(map(int, cell.split(","))) for cell in grid["filled"]}
        endpoint = (grid["rows"] - 1, grid["cols"] - 1)
        routes = []

        def visit(row, column, path):
            if (row, column) in blocked:
                return
            if (row, column) == endpoint:
                routes.append(path)
            if column < endpoint[1]:
                visit(row, column + 1, path + "r")
            if row < endpoint[0]:
                visit(row + 1, column, path + "d")

        visit(0, 0, "")
        parts = self.parts(item)
        self.assertEqual(set(parts), {"routes", "count"})
        offered = {option["id"] for option in parts["routes"]["options"]}
        all_monotone = {"".join(chars) for chars in itertools.permutations("rrdd")}
        self.assertEqual(offered, all_monotone)
        self.assertEqual(offered - set(routes), {"rrdd"})
        self.selected(parts["routes"], routes)
        self.numeric(parts["count"], len(routes))
        for option in parts["routes"]["options"]:
            arrows = option["id"].replace("r", "→").replace("d", "↓")
            self.assertEqual(option["label"], {"de": arrows, "en": arrows})

    def test_reverse_stock_replays_the_story_in_forward_order(self):
        item = self.item("mz10_reverse_two_stage_stock")
        prompt = item["prompt"]["en"]
        handed_out = int(re.search(r"another (\d+) stickers altogether", prompt)[1])
        remaining = int(re.search(r"Afterwards, (\d+) remain", prompt)[1])
        self.assertIn("Exactly half", prompt)
        start = (handed_out + remaining) * 2
        self.assertEqual(start - start // 2 - handed_out, remaining)
        self.assertNotEqual(remaining * 2 + handed_out, start)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"model", "start"})
        self.numeric(parts["start"], start)
        self.chosen(parts["model"], "undo_then_double")
        correct = next(option for option in parts["model"]["options"] if option["id"] == "undo_then_double")
        self.assertEqual(correct["label"]["en"], f"({remaining} + {handed_out}) × 2")

    def test_joined_edges_recomputed_by_neighbour_enumeration(self):
        item = self.item("mr08_joined_and_exposed_edges")
        tiles = {tuple(map(int, cell.split(","))) for cell in item["figure"]["data"]["filled"]}
        side = int(re.search(r"Each tile edge is (\d+) cm", item["prompt"]["en"])[1])
        neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        boundary_edges = sum((row + dr, col + dc) not in tiles
                             for row, col in tiles for dr, dc in neighbours)
        shared_edges = sum((row + dr, col + dc) in tiles
                           for row, col in tiles for dr, dc in [(1, 0), (0, 1)])
        self.assertEqual(len(tiles) * 4 - 2 * shared_edges, boundary_edges)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"shared", "boundary", "reason"})
        self.numeric(parts["shared"], shared_edges)
        self.numeric(parts["boundary"], side * boundary_edges)
        self.assertEqual(parts["boundary"]["unit"], "cm")
        self.chosen(parts["reason"], "shared_twice")

    def test_tiling_uses_the_whole_corner_piece_and_no_given_cell(self):
        item = self.item("mr02_square_and_corner_piece")
        parts = self.parts(item)
        self.assertEqual(set(parts), {"second_piece", "covered"})
        grid = parts["second_piece"]["figure"]["data"]
        whole = {(row, col) for row in range(grid["rows"]) for col in range(grid["cols"])}
        given = {tuple(map(int, cell.split(","))) for cell in grid["filled"]}
        remainder = whole - given
        self.assertEqual(given, {(0, 0), (0, 1), (1, 0), (1, 1)})
        last_row = {(grid["rows"] - 1, col) for col in range(grid["cols"])}
        last_column = {(row, grid["cols"] - 1) for row in range(grid["rows"])}
        self.assertEqual(remainder, last_row | last_column)
        self.assertEqual(len(remainder), len(last_row) + len(last_column) - 1)
        self.assertEqual(len(remainder), 5)
        self.selected(parts["second_piece"], {f"{row},{col}" for row, col in remainder})
        self.numeric(parts["covered"], len(whole))

    def test_overlap_area_uses_union_not_sum_of_areas(self):
        item = self.item("mr03_overlapping_rectangles_union")
        bounds = re.findall(r"rows (\d+) and (\d+), columns (\d+) to (\d+)", item["prompt"]["en"])
        self.assertEqual(len(bounds), 2)
        rectangles = []
        for first_row, last_row, first_col, last_col in bounds:
            rectangles.append({(row, col)
                               for row in range(int(first_row) - 1, int(last_row))
                               for col in range(int(first_col) - 1, int(last_col))})
        first, second = rectangles
        self.assertEqual({tuple(map(int, cell.split(","))) for cell in item["figure"]["data"]["filled"]}, first)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"overlap", "covered"})
        self.numeric(parts["overlap"], len(first & second))
        self.numeric(parts["covered"], len(first | second))
        self.assertEqual(len(first | second), len(first) + len(second) - len(first & second))
        for part in parts.values():
            self.assertEqual(part["unit"], "cm²")

    def test_both_views_enumerate_all_hidden_tower_heights_and_non_uniqueness(self):
        item = self.item("mr06_two_views_hidden_tower")
        prompt = item["prompt"]["en"]
        front = tuple(map(int, re.search(r"front view has height (\d+) on the left and (\d+) on the right", prompt).groups()))
        right = tuple(map(int, re.search(r"right view has height (\d+) for the back row and (\d+) for the front row", prompt).groups()))
        low, high = map(int, re.search(r"whole number from (\d+) to (\d+)", prompt).groups())
        rows = [row[1:] for row in item["figure"]["data"]["rows"]]
        possible = []
        for height in range(low, high + 1):
            towers = [[height if value == "x" else int(value) for value in row] for row in rows]
            front_view = tuple(max(row[col] for row in towers) for col in range(2))
            right_view = tuple(max(row) for row in towers)
            if (front_view, right_view) == (front, right):
                possible.append(str(height))
        self.assertGreater(len(possible), 1)
        self.assertLess(len(possible), high - low + 1)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"possible", "unique"})
        self.selected(parts["possible"], possible)
        self.chosen(parts["unique"], "yes" if len(possible) == 1 else "no")

    def test_deposit_refund_is_exact_in_cents(self):
        item = self.item("mg04_deposit_and_refund")
        prompt = item["prompt"]["en"]
        amounts = [Decimal(value) for value in re.findall(r"€(\d+\.\d{2})", prompt)]
        drink, deposit, refund_each = amounts
        purchased = int(re.search(r"buy (\d+) bottles", prompt)[1])
        returned = int(re.search(r"return (\d+) empty", prompt)[1])
        payment = purchased * (drink + deposit)
        refund = returned * refund_each
        self.assertEqual(deposit, refund_each)
        self.assertEqual(payment - refund, purchased * drink + (purchased - returned) * deposit)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"payment", "refund", "net"})
        for part_id, value in {"payment": payment, "refund": refund, "net": payment - refund}.items():
            self.numeric(parts[part_id], value)
            self.assertEqual(parts[part_id]["unit"], "€")
            self.assertEqual(value * 100, (value * 100).to_integral_value())

    def test_pour_return_conserves_the_original_volume(self):
        item = self.item("mg07_pour_and_return")
        prompt = item["prompt"]["en"]
        litres = int(re.search(r"contains (\d+) litre", prompt)[1])
        ml_per_litre = int(re.search(r"1 litre = (\d+) ml", prompt)[1])
        first = int(re.search(r"First pour (\d+) ml", prompt)[1])
        returned = int(re.search(r"Then pour exactly (\d+) ml", prompt)[1])
        cup, jug = first - returned, litres * ml_per_litre - first + returned
        self.assertGreaterEqual(cup, 0)
        self.assertGreaterEqual(jug, 0)
        self.assertEqual(cup + jug, litres * ml_per_litre)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"cup", "jug"})
        self.numeric(parts["cup"], cup)
        self.numeric(parts["jug"], jug)
        self.assertTrue(all(part["unit"] == "ml" for part in parts.values()))

    def test_fixed_fee_is_not_multiplied_by_quantity(self):
        item = self.item("mg04_offers_with_fixed_charge")
        prompt = item["prompt"]["en"]
        quantity = int(re.search(r"exactly (\d+) rental chairs", prompt)[1])
        fee, first_rate, second_rate = [Decimal(value) for value in re.findall(r"€(\d+)", prompt)]
        first = fee + quantity * first_rate
        second = quantity * second_rate
        self.assertNotEqual(first, quantity * (fee + first_rate))
        parts = self.parts(item)
        self.assertEqual(set(parts), {"a", "b", "cheaper"})
        self.numeric(parts["a"], first)
        self.numeric(parts["b"], second)
        self.chosen(parts["cheaper"], "a" if first < second else "b" if second < first else "equal")
        self.assertEqual(parts["a"]["unit"], "€")
        self.assertEqual(parts["b"]["unit"], "€")

    def test_overlapping_times_use_later_finish_then_wait(self):
        item = self.item("mg05_overlapping_preparations")
        prompt = item["prompt"]["en"]
        hour, minute = map(int, re.search(r"At (\d+):(\d+)", prompt).groups())
        warmup = int(re.search(r"for (\d+) minutes", prompt)[1])
        preparation = int(re.search(r"lasting (\d+) minutes", prompt)[1])
        wait = int(re.search(r"wait of exactly (\d+) minutes", prompt)[1])
        start = 60 * hour + minute
        finish = max(start + warmup, start + preparation) + wait
        self.assertLess(finish - start, warmup + preparation + wait)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"elapsed", "start", "reason"})
        self.numeric(parts["elapsed"], finish - start)
        self.assertEqual(parts["elapsed"]["unit"], "min")
        self.chosen(parts["start"], f"{finish // 60:02}{finish % 60:02}")
        self.manual(parts["reason"], ["same time", f"{preparation}-minute", f"{wait}-minute"])

    def test_tally_values_count_marks_not_groups(self):
        item = self.item("md02_tally_frequency_table")
        parts = self.parts(item)
        rows = item["figure"]["data"]["rows"]
        self.assertEqual(set(parts), {row[0].lower() for row in rows})
        for label, strokes in rows:
            self.assertRegex(strokes, r"^[| ]+$")
            self.numeric(parts[label.lower()], strokes.count("|"))
        self.assertGreater(rows[0][1].count("|"), len(rows[0][1].split()))

    def test_largest_category_is_not_a_strict_majority(self):
        item = self.item("md03_largest_is_not_majority")
        data = item["figure"]["data"]
        counts = dict(zip(data["labels"], data["values"]))
        total = sum(counts.values())
        half = Fraction(total, 2)
        self.assertEqual(max(counts, key=counts.get), "A")
        self.assertLess(counts["A"], half)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"total", "claim", "reason"})
        self.numeric(parts["total"], total)
        self.chosen(parts["claim"], "yes" if counts["A"] > half else "no")
        self.manual(parts["reason"], [f"half of {total} is {half}", f"{counts['A']} votes", "largest"])

    def test_differently_scaled_charts_compare_values_not_pixels(self):
        item = self.item("md03_compare_different_chart_scales")
        parts = self.parts(item)
        self.assertEqual(set(parts), {"monday", "difference", "two_days"})
        first = item["figure"]["data"]
        second = parts["monday"]["figure"]["data"]
        self.assertEqual(first["labels"], second["labels"])
        self.assertNotEqual(first["step"], second["step"])
        a, b = first["values"][0], second["values"][0]
        self.assertEqual(Fraction(a, first["max"]), Fraction(b, second["max"]))
        self.assertNotEqual(a, b)
        self.chosen(parts["monday"], "a" if a > b else "b" if b > a else "equal")
        self.numeric(parts["difference"], abs(a - b))
        totals = sum(first["values"]), sum(second["values"])
        self.chosen(parts["two_days"], "a" if totals[0] > totals[1] else "b" if totals[1] > totals[0] else "equal")

    def test_fair_game_enumerates_ordered_outcomes_including_no_score(self):
        item = self.item("md05_fair_game_with_no_score")
        shown = {tuple(cell["en"].lower() for cell in row) for row in item["figure"]["data"]["rows"]}
        outcomes = set(itertools.product(["red", "blue"], repeat=2))
        self.assertEqual(shown, outcomes)
        ari = {pair for pair in outcomes if pair == ("red", "red")}
        bo = {pair for pair in outcomes if pair == ("blue", "blue")}
        neither = outcomes - ari - bo
        self.assertTrue(ari.isdisjoint(bo))
        self.assertEqual(Fraction(len(ari), len(outcomes)), Fraction(len(bo), len(outcomes)))
        self.assertEqual(len(neither), 2)
        parts = self.parts(item)
        self.assertEqual(set(parts), {"fair", "neither", "reason"})
        self.chosen(parts["fair"], "same" if len(ari) == len(bo) else "ari" if len(ari) > len(bo) else "bo")
        self.numeric(parts["neither"], len(neither))
        self.manual(parts["reason"], ["exactly one", "other two", "neither"])

    def test_extension_print_output_keeps_each_solution_in_the_key_only(self):
        for index, item in enumerate(self.new_tasks, 1):
            for language in ("de", "en"):
                with self.subTest(item=item["id"], language=language):
                    learner = render_task(item, index, language, False)
                    key = render_task(item, index, language, True)
                    self.assertNotIn('class="solution"', learner)
                    self.assertNotIn('class="rubric"', learner)
                    self.assertIn('class="solution"', key)
                    # Insert unique canaries so a correct answer also appearing
                    # legitimately among the givens cannot hide a payload leak.
                    probe = copy.deepcopy(item)
                    probe["solution"][language] = "EXTENSION_WORKED_CANARY"
                    probe["hints"][0][language] = "EXTENSION_HINT_CANARY"
                    rendered = render_task(probe, index, language, False)
                    self.assertNotIn("EXTENSION_WORKED_CANARY", rendered)
                    self.assertNotIn("EXTENSION_HINT_CANARY", rendered)


if __name__ == "__main__":
    unittest.main()
